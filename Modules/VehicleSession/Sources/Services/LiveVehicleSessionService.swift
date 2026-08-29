import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain

public actor LiveVehicleSessionService: VehicleSessionService {
    let useCases: VehicleSessionUseCases
    let speedResolver: VehicleSpeedResolver
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
    var isIMUMonitoring = false
    var motionCalibrationTask: Task<Void, Never>?
    var batteryHealthTask: Task<Void, Never>?
    var batteryHealthStartTask: Task<Void, Never>?
    var batteryHealthStopTask: Task<Void, Never>?
    var batteryHealthConsumers: Set<UUID> = []
    var powerModeRefreshTask: Task<Void, Never>?
    var pendingPowerModeRefresh: VehiclePowerModeRefreshRequest?
    var visitedPowerModeIndex: Int?
    var didAttemptPowerModeBaseRefresh = false
    var didAttemptPowerModeTractionRefresh = false
    var observers: [UUID: AsyncStream<VehicleSessionSnapshot>.Continuation] = [:]

    public init(
        useCases: VehicleSessionUseCases,
        speedResolver: VehicleSpeedResolver,
        motionEstimator: VehicleMotionEstimator
    ) {
        self.useCases = useCases
        self.speedResolver = speedResolver
        self.motionEstimator = motionEstimator
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        deviceSpeedTask?.cancel()
        deviceSpeedExpiryTask?.cancel()
        imuExpiryTask?.cancel()
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
        guard observationTasks.isEmpty else { return }
        observeSources()
    }

    public func stop() async {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        deviceSpeedTask?.cancel()
        deviceSpeedTask = nil
        deviceSpeedExpiryTask?.cancel()
        deviceSpeedExpiryTask = nil
        deviceSpeedSample = nil
        locationConsumers.removeAll()
        imuExpiryTask?.cancel()
        imuExpiryTask = nil
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
        batteryHealthMonitoringState = .inactive
        batteryHealth = .init()
        powerModeRefreshTask?.cancel()
        powerModeRefreshTask = nil
        pendingPowerModeRefresh = nil
        visitedPowerModeIndex = nil
        didAttemptPowerModeBaseRefresh = false
        didAttemptPowerModeTractionRefresh = false
        publish()
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
        if required {
            batteryHealthConsumers.insert(consumerID)
            if batteryHealthMonitoringState == .inactive || isMonitoringFailed {
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

    private var isMonitoringFailed: Bool {
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
