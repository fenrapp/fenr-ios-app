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
    let sleep: @Sendable (Duration) async throws -> Void
    var recorder: CurrentTripRecorder
    var vehicleSnapshot = VehicleSessionSnapshot()
    var observationTasks: [Task<Void, Never>] = []
    var preparationTask: Task<Void, Never>?
    var tickerTask: Task<Void, Never>?
    var stopTask: Task<Void, Never>?
    var isPrepared = false
    var lastPersistenceDate: Date?
    var lastElectricalSampleDate: Date?
    var lastMotionSampleDate: Date?
    var lastAltitudeSampleDate: Date?
    var historyRevision = 0
    let locationConsumerID = UUID()
    var locationRequestTask: Task<Void, Never>?
    var isRequestingLocation = false
    var livePowerSamples: [RideElectricalPowerSample] = []
    var observers: [UUID: AsyncStream<RideSessionSnapshot>.Continuation] = [:]

    public init(
        useCases: RideSessionUseCases,
        vehicleSession: any VehicleSessionService,
        persistence: RideSessionPersistenceCoordinator,
        identityResolver: any RideVehicleIdentityResolving,
        initialContext: BikeSessionContext,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.useCases = useCases
        self.vehicleSession = vehicleSession
        self.persistence = persistence
        self.identityResolver = identityResolver
        self.now = now
        self.sleep = sleep
        recorder = CurrentTripRecorder(context: initialContext)
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        preparationTask?.cancel()
        tickerTask?.cancel()
        stopTask?.cancel()
        // The final lease release deliberately outlives the service.
        if isRequestingLocation {
            let previousRequest = locationRequestTask
            let vehicleSession = vehicleSession
            let consumerID = locationConsumerID
            Task {
                await previousRequest?.value
                await vehicleSession.setLocationMonitoringRequired(false, consumerID: consumerID)
            }
        }
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

    public func start() async {
        if let stopTask {
            await stopTask.value
            self.stopTask = nil
        }
        guard observationTasks.isEmpty else { return }
        observeVehicleSession()
    }

    public func stop() async {
        if let stopTask {
            await stopTask.value
            self.stopTask = nil
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performStop()
        }
        stopTask = task
        await task.value
        stopTask = nil
    }

    public func persistCurrentTrip() async {
        guard stopTask == nil else { return }
        guard let trip = updateTripAtCurrentTime() else { return }
        await persistence.saveActiveTrip(trip)
        lastPersistenceDate = trip.updatedAt
        publish()
        await persistence.flush()
    }

    public func completeCurrentTrip() async {
        guard stopTask == nil else { return }
        await finalizeCurrentTrip()
    }

    func finalizeCurrentTrip() async {
        let date = now()
        guard let trip = updateTripAtCurrentTime() else {
            await persistence.flush()
            return
        }
        recorder.clear()
        livePowerSamples.removeAll()
        lastMotionSampleDate = nil
        lastAltitudeSampleDate = nil
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
        guard stopTask == nil, isPrepared, let trip = recorder.trip else { return }
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
        guard stopTask == nil else { return }
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
        lastMotionSampleDate = nil
        lastAltitudeSampleDate = nil
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

    @discardableResult
    public func deleteCompletedTrip(id: UUID, vin: String) async -> Bool {
        guard stopTask == nil else { return false }
        guard recorder.context.vehicleIdentity.confirmedVIN == vin else { return false }
        let didDelete = await persistence.deleteCompletedTrip(id: id, vin: vin)
        guard didDelete else { return false }
        historyRevision += 1
        publish()
        return true
    }
}

private extension LiveRideSessionService {
    func performStop() async {
        let tasksToDrain = observationTasks
        tasksToDrain.forEach { $0.cancel() }
        for task in tasksToDrain {
            await task.value
        }
        observationTasks.removeAll()

        let preparationToDrain = preparationTask
        preparationToDrain?.cancel()
        await preparationToDrain?.value
        preparationTask = nil

        let tickerToDrain = tickerTask
        tickerToDrain?.cancel()
        await tickerToDrain?.value
        tickerTask = nil

        await finalizeCurrentTrip()
        updateTripLocationMonitoring()
        await locationRequestTask?.value
        locationRequestTask = nil
        await persistence.flush()
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
            historyRevision: historyRevision,
            batteryStateOfChargePercent: vehicleSnapshot.telemetry.batteryLevel.percent,
            batteryCapacityWattHours: vehicleSnapshot.settings.batteryPackCapacity(
                forVIN: recorder.context.vehicleIdentity.confirmedVIN
            ).wattHours,
            motion: vehicleSnapshot.motion,
            isCanonicalTelemetryAvailable: vehicleSnapshot.isCanonicalTelemetryAvailable
        )
    }

    var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = vehicleSnapshot.connection.state { true } else { false }
    }

    func publish() {
        updateTripLocationMonitoring()
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
