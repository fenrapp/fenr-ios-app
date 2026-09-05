import AsyncSupport
import BikeDomain
import Foundation

enum BikeEmulatorLifecycleState: Equatable, Sendable {
    case stopped
    case starting
    case started
    case stopping
}

public actor BikeEmulatorRepository: BikeRepository, BikeIMURepository, BikeBatteryHealthRepository,
    BikeChargePowerControlRepository, BikeDiscoveryRepository {
    let telemetryHub: AsyncEventHub<BikeTelemetry>
    let connectionHub: AsyncEventHub<BikeConnection>
    let imuHub: AsyncEventHub<BikeIMUSample>
    let debugEventHub: AsyncEventHub<BikeDebugEvent>
    let batteryHealthHub: AsyncEventHub<BikeBatteryHealth>
    let captureHub: BikeEmulatorCaptureHub
    let discoveredBikesHub: AsyncEventHub<[DiscoveredBike]>
    let powerCalculator: BikePowerTelemetryCalculator
    let runtime: BikeEmulatorRuntime
    let configuration: BikeEmulatorConfiguration
    var distanceKilometers: Double

    var scenario: BikeEmulatorScenario
    var powerModePreset: BikeEmulatorPowerModePreset
    var activeMapNumber: Int
    var tick = 0
    var isConnected = false
    var isDiscovering = false
    var batteryHealthMonitoringLeaseCount = 0
    var imuMonitoringLeaseCount = 0
    var chargePowerLimitWatts = BikeEmulatorConstants.defaultChargePowerWatts
    var chargeTargetPercent = BikeEmulatorConstants.defaultChargeTargetPercent
    var powerModeOverrides: [Int: BikePowerModeConfiguration] = [:]
    var preparedPowerModeIndexes = Set<Int>()
    var preparedTractionControlIndexes = Set<Int>()
    var isChargePowerPrepared = false
    var isBikeLockPrepared = false
    var isBikeLocked = false
    var lastPublishedConnection: BikeConnection?

    private(set) var lifecycleState: BikeEmulatorLifecycleState = .stopped
    var generation: UInt64 = 0
    var startupTask: Task<Void, Never>?
    var updateTask: Task<Void, Never>?
    var imuUpdateTask: Task<Void, Never>?
    var shutdownTask: Task<Void, Never>?

    init(
        scenario: BikeEmulatorScenario,
        powerModePreset: BikeEmulatorPowerModePreset,
        activeMapNumber: Int,
        channels: BikeEmulatorChannels,
        powerCalculator: BikePowerTelemetryCalculator,
        runtime: BikeEmulatorRuntime,
        configuration: BikeEmulatorConfiguration
    ) {
        self.scenario = scenario
        self.powerModePreset = powerModePreset
        self.activeMapNumber = max(1, min(5, activeMapNumber))
        telemetryHub = channels.telemetry
        connectionHub = channels.connection
        imuHub = channels.imu
        debugEventHub = channels.debugEvent
        batteryHealthHub = channels.batteryHealth
        captureHub = channels.capture
        discoveredBikesHub = channels.discoveredBikes
        self.powerCalculator = powerCalculator
        self.runtime = runtime
        self.configuration = configuration
        let saved = configuration.initialState
        distanceKilometers = saved.distanceKilometers
        chargePowerLimitWatts = saved.chargePowerWatts
        chargeTargetPercent = saved.chargeTargetPercent
        isBikeLocked = saved.isBikeLocked
        powerModeOverrides = Dictionary(uniqueKeysWithValues: saved.maps.map { ($0.index, $0.configuration) })
    }

    deinit {
        startupTask?.cancel()
        updateTask?.cancel()
        imuUpdateTask?.cancel()
        shutdownTask?.cancel()
    }

    public func start() async {
        while !Task.isCancelled {
            switch lifecycleState {
            case .stopped:
                beginStart()
                guard let task = startupTask else { return }
                let startGeneration = generation
                await task.value
                completeStart(generation: startGeneration)
                return
            case .starting:
                guard let task = startupTask else { return }
                let startGeneration = generation
                await task.value
                completeStart(generation: startGeneration)
                return
            case .started:
                return
            case .stopping:
                guard let task = shutdownTask else { return }
                await task.value
            }
        }
    }

    public func stop() async {
        switch lifecycleState {
        case .stopped:
            return
        case .stopping:
            await shutdownTask?.value
        case .starting, .started:
            beginStop()
            await shutdownTask?.value
        }
    }

    public func connect(vin: String) async throws {
        try Task.checkCancellation()
        if configuration.isDemo, vin != configuration.vin || lifecycleState != .started {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        isConnected = true
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Connected to \(scenario.displayName)")
    }

    public func disconnect() async throws {
        isConnected = false
        invalidateControlPreparations()
        await publishConnectionIfChanged(
            BikeConnection(state: .disconnected(reason: "Debug disconnect"))
        )
        await publishDebugEvent(title: "Emulator", detail: "Disconnected")
    }

    public func retrySecurityHandshake() async throws {
        try Task.checkCancellation()
        if configuration.isDemo, lifecycleState != .started {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        isConnected = true
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Security handshake simulated")
    }

    public func readTelemetrySnapshot() async throws {
        await publishCurrentState()
    }

    func invalidateControlPreparations() {
        preparedPowerModeIndexes.removeAll()
        preparedTractionControlIndexes.removeAll()
        isChargePowerPrepared = false
        isBikeLockPrepared = false
    }

    private func beginStart() {
        generation &+= 1
        let startGeneration = generation
        isConnected = true
        lifecycleState = .starting
        startupTask = Task { [weak self] in
            await self?.publishCurrentState(expectedGeneration: startGeneration)
        }
    }

    private func completeStart(generation startGeneration: UInt64) {
        guard lifecycleState == .starting,
              generation == startGeneration
        else { return }

        startupTask = nil
        lifecycleState = .started
        scheduleUpdates(generation: startGeneration)
        if imuMonitoringLeaseCount > 0 {
            scheduleIMUUpdates(generation: startGeneration)
        }
    }

    private func beginStop() {
        generation &+= 1
        let stopGeneration = generation
        lifecycleState = .stopping
        isConnected = false
        invalidateControlPreparations()

        let startupTask = startupTask
        let updateTask = updateTask
        let imuUpdateTask = imuUpdateTask
        startupTask?.cancel()
        updateTask?.cancel()
        imuUpdateTask?.cancel()

        shutdownTask = Task { [weak self] in
            await startupTask?.value
            await updateTask?.value
            await imuUpdateTask?.value
            await self?.completeStop(generation: stopGeneration)
        }
    }

    private func completeStop(generation stopGeneration: UInt64) async {
        guard lifecycleState == .stopping,
              generation == stopGeneration
        else { return }

        batteryHealthMonitoringLeaseCount = 0
        imuMonitoringLeaseCount = 0
        isDiscovering = false
        lastPublishedConnection = nil
        await telemetryHub.send(BikeTelemetry())
        await publishConnectionIfChanged(BikeConnection())
        await batteryHealthHub.send(BikeBatteryHealth())
        await discoveredBikesHub.send([])
        await captureHub.reset()

        startupTask = nil
        updateTask = nil
        imuUpdateTask = nil
        shutdownTask = nil
        lifecycleState = .stopped
    }
}

enum BikeEmulatorConstants {
    static let defaultChargePowerWatts = 1_000
    static let defaultChargeTargetPercent = 100
    static let minimumChargePowerWatts = 300
    static let maximumChargePowerWatts = 3_300
    static let minimumChargeTargetPercent = 1
    static let maximumChargeTargetPercent = 100
    static let chargingBusVoltage = 388.4
    static let noOpWriteHex = "DEBUG NO-OP 4005"
    static let powerModeHorsepowerRange = 10 ... 80
    static let powerModeRegenerationRange = -100 ... 100
    static let tractionControlRange = -100.0 ... 100.0
    static let debugOneGRaw = 1_000.0
}
