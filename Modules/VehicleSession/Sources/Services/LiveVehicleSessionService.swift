import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain

public actor LiveVehicleSessionService: VehicleSessionService {
    let useCases: VehicleSessionUseCases
    let powerModeRefreshCoordinator: VehiclePowerModeRefreshCoordinator
    let batteryHealthMonitoringCoordinator: VehicleBatteryHealthMonitoringCoordinator
    let speedResolver: VehicleSpeedResolver
    let sleep: @Sendable (Duration) async throws -> Void
    var motionEstimator: VehicleMotionEstimator
    var telemetry = BikeTelemetry()
    var telemetryRevision = 0
    var minimumCanonicalTelemetryRevision = 0
    var connection = BikeConnection()
    var settings = AppSettings()
    var profile: BikeProfile?
    var deviceHeadingSample: DeviceHeadingSample?
    var deviceHeadingTask: Task<Void, Never>?
    var deviceHeadingExpiryTask: Task<Void, Never>?
    var deviceHeadingGeneration = 0
    var deviceSpeedSample: DeviceSpeedSample?
    var devicePositionSample: DeviceSpeedSample?
    var devicePositionExpiryTask: Task<Void, Never>?
    var deviceLocationGeneration = 0
    var imuSample: BikeIMUSample?
    var motionCalibration: VehicleMotionCalibration?
    var hasLoadedMotionCalibration = false
    var motion = VehicleMotionSnapshot()
    var batteryHealthSnapshot = VehicleBatteryHealthMonitoringCoordinator.Snapshot()
    var hasReceivedSettings = false
    var hasReceivedProfile = false
    var observationTasks: [Task<Void, Never>] = []
    var deviceSpeedTask: Task<Void, Never>?
    var deviceSpeedExpiryTask: Task<Void, Never>?
    var locationConsumers: Set<UUID> = []
    var imuExpiryTask: Task<Void, Never>?
    var imuMonitoringStartTask: Task<Void, Never>?
    var imuMonitoringStartGeneration: Int?
    var imuMonitoringGeneration = 0
    var isIMUMonitoring = false
    var motionCalibrationTask: Task<Void, Never>?
    var batteryHealthBridgeTask: Task<Void, Never>?
    var observers: [UUID: AsyncStream<VehicleSessionSnapshot>.Continuation] = [:]
    var isStopping = false
    var shouldStartAfterStopping = false

    public init(
        useCases: VehicleSessionUseCases,
        powerModeRefreshCoordinator: VehiclePowerModeRefreshCoordinator,
        batteryHealthMonitoringCoordinator: VehicleBatteryHealthMonitoringCoordinator,
        speedResolver: VehicleSpeedResolver,
        motionEstimator: VehicleMotionEstimator,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.useCases = useCases
        self.powerModeRefreshCoordinator = powerModeRefreshCoordinator
        self.batteryHealthMonitoringCoordinator = batteryHealthMonitoringCoordinator
        self.speedResolver = speedResolver
        self.motionEstimator = motionEstimator
        self.sleep = sleep
    }

    deinit {
        let powerModeRefreshCoordinator = powerModeRefreshCoordinator
        Task { await powerModeRefreshCoordinator.reset() }
        let batteryHealthMonitoringCoordinator = batteryHealthMonitoringCoordinator
        Task { await batteryHealthMonitoringCoordinator.stop() }
        observationTasks.forEach { $0.cancel() }
        deviceHeadingTask?.cancel()
        deviceHeadingExpiryTask?.cancel()
        deviceSpeedTask?.cancel()
        deviceSpeedExpiryTask?.cancel()
        devicePositionExpiryTask?.cancel()
        imuExpiryTask?.cancel()
        imuMonitoringStartTask?.cancel()
        motionCalibrationTask?.cancel()
        batteryHealthBridgeTask?.cancel()
    }

    public func observe() -> AsyncStream<VehicleSessionSnapshot> {
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
        guard !isStopping else {
            shouldStartAfterStopping = true
            return
        }
        guard observationTasks.isEmpty else { return }
        observeBatteryHealthCoordinator()
        observeSources()
    }

    public func stop() async {
        guard !isStopping else { return }
        isStopping = true
        shouldStartAfterStopping = false
        imuMonitoringGeneration &+= 1
        imuMonitoringStartTask?.cancel()
        let tasksToDrain = observationTasks
        tasksToDrain.forEach { $0.cancel() }
        for task in tasksToDrain {
            await task.value
        }
        observationTasks.removeAll()
        await stopDeviceHeadingObservation()
        await stopDeviceLocationObservation()
        locationConsumers.removeAll()
        imuExpiryTask?.cancel()
        imuExpiryTask = nil
        if let imuMonitoringStartTask {
            await imuMonitoringStartTask.value
        }
        if isIMUMonitoring {
            await useCases.stopIMUMonitoring.execute()
            isIMUMonitoring = false
        }
        motionCalibrationTask?.cancel()
        motionCalibrationTask = nil
        imuSample = nil
        motionCalibration = nil
        hasLoadedMotionCalibration = false
        motionEstimator.reset()
        motion = .init()
        let stoppedBatteryHealthSnapshot = await batteryHealthMonitoringCoordinator.stop()
        batteryHealthBridgeTask?.cancel()
        if let batteryHealthBridgeTask {
            await batteryHealthBridgeTask.value
        }
        batteryHealthBridgeTask = nil
        applyBatteryHealthSnapshot(stoppedBatteryHealthSnapshot)
        minimumCanonicalTelemetryRevision = telemetryRevision + 1
        await powerModeRefreshCoordinator.reset()
        publish()
        isStopping = false
        if shouldStartAfterStopping {
            shouldStartAfterStopping = false
            observeBatteryHealthCoordinator()
            observeSources()
        }
    }

    public func refreshBikeStatus() async {
        try? await useCases.readBikeStatusSnapshot.execute()
    }

    public func zeroBikeAttitude() async {
        guard profile != nil,
              imuSample != nil,
              motion.availability == .available || motion.availability == .zeroing
        else {
            return
        }
        motionEstimator.requestZero()
        await refreshMotion()
        publish()
    }

    public func setBatteryHealthMonitoringRequired(_ required: Bool, consumerID: UUID) async {
        guard !isStopping else { return }
        let preparedSnapshot = await batteryHealthMonitoringCoordinator.prepareLeaseChange(
            required: required,
            consumerID: consumerID,
            isSessionReady: isReceivingTelemetry
        )
        if applyBatteryHealthSnapshot(preparedSnapshot) {
            publish()
        }
        await batteryHealthMonitoringCoordinator.resumePendingWork()
    }

    public func setLocationMonitoringRequired(_ required: Bool, consumerID: UUID) async {
        if required {
            locationConsumers.insert(consumerID)
        } else {
            locationConsumers.remove(consumerID)
        }
        await updateDeviceSpeedObservation()
        publish()
    }
}

extension LiveVehicleSessionService {
    var snapshot: VehicleSessionSnapshot {
        .init(
            telemetry: telemetry,
            connection: connection,
            settings: settings,
            profile: profile,
            resolvedSpeedKilometersPerHour: speedResolver.resolvedSpeed(
                motorcycleKilometersPerHour: telemetry.speed.kmh,
                deviceSample: deviceSpeedSample,
                source: settings.speedSource
            ),
            speedSource: settings.speedSource,
            isGPSAvailable: speedResolver.hasValidDeviceSpeed(deviceSpeedSample),
            batteryHealth: batteryHealthSnapshot.health,
            batteryHealthMonitoringState: batteryHealthSnapshot.state,
            motion: motion,
            hasReceivedSettings: hasReceivedSettings,
            hasReceivedProfile: hasReceivedProfile,
            isCanonicalTelemetryAvailable: isReceivingTelemetry
                && telemetry.lastUpdated != nil
                && telemetryRevision >= minimumCanonicalTelemetryRevision
        )
    }

    func publish() {
        let snapshot = snapshot
        observers.values.forEach { $0.yield(snapshot) }
    }

    @discardableResult
    func applyBatteryHealthSnapshot(
        _ snapshot: VehicleBatteryHealthMonitoringCoordinator.Snapshot
    ) -> Bool {
        guard snapshot.revision > batteryHealthSnapshot.revision else { return false }
        batteryHealthSnapshot = snapshot
        return true
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
