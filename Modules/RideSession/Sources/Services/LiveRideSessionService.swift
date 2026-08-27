import BikeDomain
import Foundation
import RideSessionDomain
import SettingsDomain
import VehicleSession

public actor LiveRideSessionService: RideSessionService {
    let useCases: RideSessionUseCases
    let vehicleSession: any VehicleSessionService
    let persistence: RideSessionPersistenceCoordinator
    let identityResolver: any RideVehicleIdentityResolving
    let now: @Sendable () -> Date
    var recorder: CurrentTripRecorder
    var vehicleSnapshot = VehicleSessionSnapshot()
    var observationTasks: [Task<Void, Never>] = []
    var preparationTask: Task<Void, Never>?
    var tickerTask: Task<Void, Never>?
    var isPrepared = false
    var lastPersistenceDate: Date?
    var lastElectricalSampleDate: Date?
    var historyRevision = 0
    var livePowerSamples: [RideElectricalPowerSample] = []
    var observers: [UUID: AsyncStream<RideSessionSnapshot>.Continuation] = [:]

    public init(
        useCases: RideSessionUseCases,
        vehicleSession: any VehicleSessionService,
        persistence: RideSessionPersistenceCoordinator,
        identityResolver: any RideVehicleIdentityResolving,
        initialContext: BikeSessionContext,
        now: @escaping @Sendable () -> Date
    ) {
        self.useCases = useCases
        self.vehicleSession = vehicleSession
        self.persistence = persistence
        self.identityResolver = identityResolver
        self.now = now
        recorder = CurrentTripRecorder(context: initialContext)
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        preparationTask?.cancel()
        tickerTask?.cancel()
    }

    public func observe() -> AsyncStream<RideSessionSnapshot> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            observers[id] = continuation
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    public func start() {
        guard observationTasks.isEmpty else { return }
        observeVehicleSession()
    }

    public func stop() async {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        preparationTask?.cancel()
        preparationTask = nil
        tickerTask?.cancel()
        tickerTask = nil
        await persistence.flush()
    }

    public func persistCurrentTrip() async {
        guard let trip = updateTripAtCurrentTime() else { return }
        await persistence.saveActiveTrip(trip)
        lastPersistenceDate = trip.updatedAt
        publish()
        await persistence.flush()
    }

    public func completeCurrentTrip() async {
        let date = now()
        guard let trip = updateTripAtCurrentTime() else {
            await persistence.flush()
            return
        }
        recorder.clear()
        livePowerSamples.removeAll()
        tickerTask?.cancel()
        tickerTask = nil
        publish()
        if await persistence.completeTrip(trip, at: date) {
            historyRevision += 1
            publish()
        }
    }

    public func flush() async {
        await persistence.flush()
    }

    public func togglePauseCurrentTrip() async {
        guard isPrepared, let trip = recorder.trip else { return }
        let date = now()
        if trip.isPaused {
            guard recorder.resume(
                at: date,
                odometerKilometers: vehicleSnapshot.telemetry.odometer.kilometers,
                speedKilometersPerHour: resolvedSpeed()
            ) != nil else { return }
            lastElectricalSampleDate = nil
            startTickerIfNeeded()
        } else {
            guard recorder.pause(
                at: date,
                odometerKilometers: vehicleSnapshot.telemetry.odometer.kilometers,
                speedKilometersPerHour: resolvedSpeed()
            ) != nil else { return }
            lastElectricalSampleDate = nil
            tickerTask?.cancel()
            tickerTask = nil
        }
        await persistIfNeeded(force: true)
        publish()
    }

    public func resetCurrentTrip() async {
        let date = now()
        let speed = resolvedSpeed()
        guard let trip = recorder.record(
            runState: vehicleSnapshot.telemetry.runState,
            at: date,
            odometerKilometers: vehicleSnapshot.telemetry.odometer.kilometers,
            speedKilometersPerHour: speed
        ) else { return }

        recorder.clear()
        livePowerSamples.removeAll()
        lastElectricalSampleDate = nil
        let replacement = isReceivingTelemetry
            ? recorder.record(
                runState: vehicleSnapshot.telemetry.runState,
                at: date,
                odometerKilometers: vehicleSnapshot.telemetry.odometer.kilometers,
                speedKilometersPerHour: speed
            )
            : nil
        lastPersistenceDate = replacement?.updatedAt
        if replacement != nil {
            startTickerIfNeeded()
        } else {
            tickerTask?.cancel()
            tickerTask = nil
        }
        publish()
        if await persistence.resetTrip(completing: trip, starting: replacement, at: date) {
            historyRevision += 1
            publish()
        }
    }
}

extension LiveRideSessionService {
    var snapshot: RideSessionSnapshot {
        .init(
            trip: recorder.trip,
            vehicleIdentity: recorder.context.vehicleIdentity,
            resolvedSpeedKilometersPerHour: resolvedSpeed(),
            speedSource: vehicleSnapshot.speedSource,
            measurementSystem: vehicleSnapshot.settings.measurementSystem,
            isGPSAvailable: vehicleSnapshot.isGPSAvailable,
            livePowerSamples: livePowerSamples,
            historyRevision: historyRevision
        )
    }

    var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = vehicleSnapshot.connection.state { true } else { false }
    }

    func publish() {
        let snapshot = snapshot
        observers.values.forEach { $0.yield(snapshot) }
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    func resolvedSpeed() -> Double? {
        vehicleSnapshot.hasReceivedSettings ? vehicleSnapshot.resolvedSpeedKilometersPerHour : nil
    }

    enum Constants {
        static let tickInterval = Duration.seconds(1)
        static let persistenceInterval: TimeInterval = 5
        static let minimumLiveSampleInterval: TimeInterval = 0.5
        static let liveSampleWindow: TimeInterval = 60
        static let maximumLiveSampleCount = 120
    }
}
