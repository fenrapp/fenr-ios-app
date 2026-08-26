import BikeDomain
import Combine
import EnvironmentDomain
import Foundation
import RideSessionDomain
import SettingsDomain

@MainActor
public final class CurrentTripCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardCurrentTripViewData()

    private let useCases: CurrentTripCardUseCases
    private let mapper: CurrentTripCardMapper
    private let deviceSpeedResolver: DeviceSpeedResolver
    private let now: @Sendable () -> Date
    private let onHistoryChanged: @MainActor @Sendable () -> Void
    private var recorder: CurrentTripRecorder
    private var telemetry = BikeTelemetry()
    private var connection = BikeConnection()
    private var settings = AppSettings()
    private var hasReceivedSettings = false
    private var deviceSpeedSample: DeviceSpeedSample?
    private var observationTasks: [Task<Void, Never>] = []
    private var deviceSpeedTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var storageTask: Task<Void, Never>?
    private var isPrepared = false
    private var isVisible = false
    private var lastPersistenceDate: Date?
    private var storageGeneration = 0

    public init(
        useCases: CurrentTripCardUseCases,
        mapper: CurrentTripCardMapper,
        deviceSpeedResolver: DeviceSpeedResolver,
        applicationSessionID: UUID,
        now: @escaping @Sendable () -> Date,
        onHistoryChanged: @escaping @MainActor @Sendable () -> Void
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.deviceSpeedResolver = deviceSpeedResolver
        self.now = now
        self.onHistoryChanged = onHistoryChanged
        recorder = CurrentTripRecorder(applicationSessionID: applicationSessionID)
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        deviceSpeedTask?.cancel()
        preparationTask?.cancel()
        tickerTask?.cancel()
        storageTask?.cancel()
    }

    public func start() {
        prepareIfNeeded()
        guard observationTasks.isEmpty else { return }

        let observeTelemetry = useCases.observeTelemetry
        observationTasks.append(Task { [weak self] in
            let stream = await observeTelemetry.execute()
            for await telemetry in stream {
                guard !Task.isCancelled else { return }
                self?.receive(telemetry)
            }
        })

        let observeConnection = useCases.observeConnection
        observationTasks.append(Task { [weak self] in
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.connection = connection
                self?.updateTripAndPresentation()
            }
        })

        let observeSettings = useCases.observeSettings
        observationTasks.append(Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.hasReceivedSettings = true
                self?.settings = settings
                self?.updateDeviceSpeedObservation()
                self?.renderIfVisible()
            }
        })
    }

    public func stop() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        deviceSpeedTask?.cancel()
        deviceSpeedTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        tickerTask?.cancel()
        tickerTask = nil
    }

    public func setIsVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else { return }
        self.isVisible = isVisible
        renderIfVisible()
    }

    public func persistCurrentTrip() {
        guard recorder.tick(
            at: now(),
            speedKilometersPerHour: resolvedSpeed()
        ) != nil else { return }
        persistIfNeeded(force: true)
        renderIfVisible()
    }

    public func completeCurrentTrip() {
        let date = now()
        guard let trip = recorder.tick(
            at: date,
            speedKilometersPerHour: resolvedSpeed()
        ) else { return }
        recorder.clear()
        tickerTask?.cancel()
        tickerTask = nil
        enqueueCompletion(trip, at: date)
        renderIfVisible()
    }

    public func togglePauseCurrentTrip() {
        guard isPrepared, let trip = recorder.trip else { return }
        let date = now()
        if trip.isPaused {
            guard recorder.resume(
                at: date,
                odometerKilometers: telemetry.odometer.kilometers,
                speedKilometersPerHour: resolvedSpeed()
            ) != nil else { return }
            startTickerIfNeeded()
        } else {
            guard recorder.pause(
                at: date,
                odometerKilometers: telemetry.odometer.kilometers,
                speedKilometersPerHour: resolvedSpeed()
            ) != nil else { return }
            tickerTask?.cancel()
            tickerTask = nil
        }
        persistIfNeeded(force: true)
        renderIfVisible()
    }

    public func resetCurrentTrip() {
        let date = now()
        let speed = resolvedSpeed()
        guard let trip = recorder.record(
            runState: telemetry.runState,
            at: date,
            odometerKilometers: telemetry.odometer.kilometers,
            speedKilometersPerHour: speed
        ) else { return }

        recorder.clear()
        let replacement = isReceivingTelemetry
            ? recorder.record(
                runState: telemetry.runState,
                at: date,
                odometerKilometers: telemetry.odometer.kilometers,
                speedKilometersPerHour: speed
            )
            : nil
        enqueueReset(completing: trip, starting: replacement, at: date)
        lastPersistenceDate = replacement?.updatedAt
        if replacement != nil {
            startTickerIfNeeded()
        } else {
            tickerTask?.cancel()
            tickerTask = nil
        }
        renderIfVisible()
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardCurrentTripViewData) {
        self.viewState = viewState
    }
#endif
}

private extension CurrentTripCardViewModel {
    private func receive(_ telemetry: BikeTelemetry) {
        self.telemetry = telemetry
        updateTripAndPresentation()
    }

    private func updateTripAndPresentation() {
        updateCurrentTrip()
        updateDeviceSpeedObservation()
        renderIfVisible()
    }

    private func updateCurrentTrip() {
        guard isPrepared, isReceivingTelemetry else { return }
        let previousTripID = recorder.trip?.id
        guard let trip = recorder.record(
            runState: telemetry.runState,
            at: now(),
            odometerKilometers: telemetry.odometer.kilometers,
            speedKilometersPerHour: resolvedSpeed()
        ) else { return }

        if previousTripID == nil {
            startTickerIfNeeded()
            persistIfNeeded(force: true)
        } else if trip.updatedAt.timeIntervalSince(lastPersistenceDate ?? .distantPast)
                    >= Constants.persistenceInterval {
            persistIfNeeded(force: false)
        }
    }

    private func prepareIfNeeded() {
        guard !isPrepared, preparationTask == nil else { return }
        let prepareRideTripSession = useCases.prepareRideTripSession
        let applicationSessionID = recorder.applicationSessionID
        preparationTask = Task { [weak self] in
            let restoredTrip = await prepareRideTripSession.execute(
                applicationSessionID: applicationSessionID
            )
            guard !Task.isCancelled else { return }
            self?.finishPreparation(restoredTrip)
        }
    }

    private func finishPreparation(_ restoredTrip: RideTrip?) {
        preparationTask = nil
        isPrepared = true
        recorder.restore(restoredTrip)
        if let restoredTrip {
            lastPersistenceDate = restoredTrip.updatedAt
            if !restoredTrip.isPaused {
                startTickerIfNeeded()
            }
        }
        updateTripAndPresentation()
    }

    private func updateDeviceSpeedObservation() {
        guard settings.speedSource.usesDeviceLocation, deviceSpeedTask == nil else {
            if !settings.speedSource.usesDeviceLocation {
                deviceSpeedTask?.cancel()
                deviceSpeedTask = nil
                deviceSpeedSample = nil
            }
            return
        }
        let observeDeviceSpeed = useCases.observeDeviceSpeed
        deviceSpeedTask = Task { [weak self] in
            let stream = await observeDeviceSpeed.execute()
            for await sample in stream {
                guard !Task.isCancelled else { return }
                self?.deviceSpeedSample = sample
                self?.updateTripAndPresentation()
            }
        }
    }

    private func resolvedSpeed() -> Double? {
        guard hasReceivedSettings else { return nil }
        return deviceSpeedResolver.resolvedSpeed(
            motorcycleKilometersPerHour: telemetry.speed.kmh,
            deviceSample: deviceSpeedSample,
            source: settings.speedSource
        )
    }

    private func startTickerIfNeeded() {
        guard tickerTask == nil else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Constants.tickInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                guard self.recorder.tick(
                    at: self.now(),
                    speedKilometersPerHour: self.resolvedSpeed()
                ) != nil else {
                    self.tickerTask = nil
                    return
                }
                self.persistIfNeeded(force: false)
                self.renderIfVisible()
            }
        }
    }

    private func renderIfVisible() {
        guard isVisible else { return }
        viewState = mapper.map(
            trip: recorder.trip,
            measurementSystem: settings.measurementSystem,
            speedSource: settings.speedSource,
            isGPSAvailable: deviceSpeedResolver.hasValidDeviceSpeed(deviceSpeedSample)
        )
    }
}

private extension CurrentTripCardViewModel {
    private func persistIfNeeded(force: Bool) {
        guard let trip = recorder.trip else { return }
        if !force,
           trip.updatedAt.timeIntervalSince(lastPersistenceDate ?? .distantPast)
            < Constants.persistenceInterval {
            return
        }
        lastPersistenceDate = trip.updatedAt
        let saveActiveRideTrip = useCases.saveActiveRideTrip
        enqueueStorageOperation { await saveActiveRideTrip.execute(trip) }
    }

    private func enqueueCompletion(_ trip: RideTrip, at date: Date) {
        let completeRideTrip = useCases.completeRideTrip
        let onHistoryChanged = onHistoryChanged
        enqueueStorageOperation {
            await completeRideTrip.execute(trip, at: date)
            await onHistoryChanged()
        }
    }

    private func enqueueReset(
        completing trip: RideTrip,
        starting replacement: RideTrip?,
        at date: Date
    ) {
        let completeRideTrip = useCases.completeRideTrip
        let saveActiveRideTrip = useCases.saveActiveRideTrip
        let onHistoryChanged = onHistoryChanged
        enqueueStorageOperation {
            await completeRideTrip.execute(trip, at: date)
            if let replacement {
                await saveActiveRideTrip.execute(replacement)
            }
            await onHistoryChanged()
        }
    }

    private func enqueueStorageOperation(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        let previousTask = storageTask
        storageGeneration += 1
        let generation = storageGeneration
        storageTask = Task { [weak self] in
            await previousTask?.value
            guard !Task.isCancelled else { return }
            await operation()
            guard !Task.isCancelled else { return }
            self?.finishStorageOperation(generation: generation)
        }
    }

    private func finishStorageOperation(generation: Int) {
        guard storageGeneration == generation else { return }
        storageTask = nil
    }

    private var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = connection.state {
            true
        } else {
            false
        }
    }

    private enum Constants {
        static let tickInterval = Duration.seconds(1)
        static let persistenceInterval: TimeInterval = 5
    }
}
