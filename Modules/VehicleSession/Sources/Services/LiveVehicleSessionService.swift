import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain

public actor LiveVehicleSessionService: VehicleSessionService {
    let useCases: VehicleSessionUseCases
    let speedResolver: VehicleSpeedResolver
    let sleep: @Sendable (Duration) async throws -> Void
    var motionEstimator: VehicleMotionEstimator
    var telemetry = BikeTelemetry()
    var connection = BikeConnection()
    var settings = AppSettings()
    var profile: BikeProfile?
    var deviceSpeedSample: DeviceSpeedSample?
    var imuSample: BikeIMUSample?
    var motionCalibration: VehicleMotionCalibration?
    var hasLoadedMotionCalibration = false
    var motion = VehicleMotionSnapshot()
    var batteryHealth = BikeBatteryHealth()
    var batteryHealthMonitoringState = VehicleBatteryHealthMonitoringState.inactive
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
    var batteryHealthTask: Task<Void, Never>?
    var batteryHealthStartTask: Task<Void, Never>?
    var batteryHealthStartGeneration: Int?
    var batteryHealthMonitoringGeneration = 0
    var batteryHealthStopTask: Task<Void, Never>?
    var batteryHealthConsumers: Set<UUID> = []
    var powerModeRefreshTask: Task<Void, Never>?
    var powerModeRefreshGeneration = 0
    var pendingPowerModeRefresh: VehiclePowerModeRefreshRequest?
    var visitedPowerModeIndex: Int?
    var didAttemptPowerModeBaseRefresh = false
    var didAttemptPowerModeTractionRefresh = false
    var observers: [UUID: AsyncStream<VehicleSessionSnapshot>.Continuation] = [:]
    var isStopping = false
    var shouldStartAfterStopping = false

    public init(
        useCases: VehicleSessionUseCases,
        speedResolver: VehicleSpeedResolver,
        motionEstimator: VehicleMotionEstimator,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.useCases = useCases
        self.speedResolver = speedResolver
        self.motionEstimator = motionEstimator
        self.sleep = sleep
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        deviceSpeedTask?.cancel()
        deviceSpeedExpiryTask?.cancel()
        imuExpiryTask?.cancel()
        imuMonitoringStartTask?.cancel()
        motionCalibrationTask?.cancel()
        batteryHealthTask?.cancel()
        batteryHealthStartTask?.cancel()
        batteryHealthStopTask?.cancel()
        powerModeRefreshTask?.cancel()
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
        deviceSpeedTask?.cancel()
        deviceSpeedTask = nil
        deviceSpeedExpiryTask?.cancel()
        deviceSpeedExpiryTask = nil
        deviceSpeedSample = nil
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
        batteryHealthMonitoringGeneration &+= 1
        batteryHealthStartTask?.cancel()
        batteryHealthConsumers.removeAll()
        if let batteryHealthStartTask {
            await batteryHealthStartTask.value
        } else if batteryHealthMonitoringState == .active {
            scheduleBatteryHealthStop()
        }
        if let batteryHealthStopTask {
            await batteryHealthStopTask.value
        }
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        batteryHealthStartGeneration = nil
        batteryHealthMonitoringState = .inactive
        batteryHealth = .init()
        resetPowerModeRefresh()
        publish()
        isStopping = false
        if shouldStartAfterStopping {
            shouldStartAfterStopping = false
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
        if required {
            batteryHealthConsumers.insert(consumerID)
            if isReceivingTelemetry,
               (batteryHealthMonitoringState == .inactive || isMonitoringFailed) {
                beginBatteryHealthMonitoring()
            }
        } else {
            batteryHealthConsumers.remove(consumerID)
            guard batteryHealthConsumers.isEmpty else { return }
            if batteryHealthMonitoringState == .active {
                scheduleBatteryHealthStop()
            } else if isMonitoringFailed {
                batteryHealthMonitoringState = .inactive
                batteryHealth = .init()
                publish()
            }
        }
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
            batteryHealth: batteryHealth,
            batteryHealthMonitoringState: batteryHealthMonitoringState,
            motion: motion,
            hasReceivedSettings: hasReceivedSettings,
            hasReceivedProfile: hasReceivedProfile
        )
    }

    var isMonitoringFailed: Bool {
        if case .failed = batteryHealthMonitoringState { true } else { false }
    }

    func publish() {
        let snapshot = snapshot
        observers.values.forEach { $0.yield(snapshot) }
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
