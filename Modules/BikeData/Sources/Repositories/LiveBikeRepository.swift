import AsyncSupport
import BikeDomain
import BikeSDK
import Foundation

enum LiveBikeRepositoryLifecycleState: Equatable, Sendable {
    case stopped
    case starting
    case started
    case stopping
}

public actor LiveBikeRepository: BikeRepository, BikeIMURepository, BikeBatteryHealthRepository,
    BikeChargePowerControlRepository, BikeDiscoveryRepository {
    private let client: BikeTelemetryClient
    private let eventHandler: LiveBikeRepositoryEventHandler
    private let stateStore: BikeRepositoryStateStore
    private let telemetryHub: AsyncEventHub<BikeTelemetry>
    private let connectionHub: AsyncEventHub<BikeConnection>
    private let debugHub: AsyncEventHub<BikeDebugEvent>
    private let imuHub: AsyncEventHub<BikeIMUSample>
    private let batteryHealthStore: BatteryHealthStateStore
    private let batteryHealthHub: AsyncEventHub<BikeBatteryHealth>
    private let batteryCaptureHub: AsyncEventHub<BatteryDatasetCapture>
    private let discoveredBikesHub: AsyncEventHub<[DiscoveredBike]>
    private let controlService: LiveBikeControlService
    private(set) var lifecycleState: LiveBikeRepositoryLifecycleState = .stopped
    private var generation: UInt64 = 0
    private var startupTask: Task<AsyncStream<BikeSDKEvent>?, Never>?
    private var eventsTask: Task<Void, Never>?
    private var shutdownTask: Task<Void, Never>?

    public init(
        client: BikeTelemetryClient,
        eventHandler: LiveBikeRepositoryEventHandler,
        stateStore: BikeRepositoryStateStore,
        telemetryHub: AsyncEventHub<BikeTelemetry>,
        connectionHub: AsyncEventHub<BikeConnection>,
        debugHub: AsyncEventHub<BikeDebugEvent>,
        imuHub: AsyncEventHub<BikeIMUSample>,
        batteryHealthStore: BatteryHealthStateStore,
        batteryHealthHub: AsyncEventHub<BikeBatteryHealth>,
        batteryCaptureHub: AsyncEventHub<BatteryDatasetCapture>,
        discoveredBikesHub: AsyncEventHub<[DiscoveredBike]>,
        controlService: LiveBikeControlService
    ) {
        self.client = client
        self.stateStore = stateStore
        self.telemetryHub = telemetryHub
        self.connectionHub = connectionHub
        self.debugHub = debugHub
        self.imuHub = imuHub
        self.batteryHealthStore = batteryHealthStore
        self.batteryHealthHub = batteryHealthHub
        self.batteryCaptureHub = batteryCaptureHub
        self.discoveredBikesHub = discoveredBikesHub
        self.controlService = controlService
        self.eventHandler = eventHandler
    }
    deinit {
        startupTask?.cancel()
        eventsTask?.cancel()
        shutdownTask?.cancel()
    }
    public func start() async {
        while !Task.isCancelled {
            switch lifecycleState {
            case .stopped:
                generation &+= 1
                let startGeneration = generation
                let client = client
                let task: Task<AsyncStream<BikeSDKEvent>?, Never> = Task {
                    guard !Task.isCancelled else { return nil }
                    await client.start()
                    guard !Task.isCancelled else { return nil }
                    let events = await client.events()
                    guard !Task.isCancelled else { return nil }
                    return events
                }
                lifecycleState = .starting
                startupTask = task
                let events = await task.value
                completeStart(events: events, generation: startGeneration)
                return
            case .starting:
                guard let task = startupTask else { return }
                let startGeneration = generation
                let events = await task.value
                completeStart(events: events, generation: startGeneration)
                return
            case .started:
                return
            case .stopping:
                guard let task = shutdownTask else { return }
                let stopGeneration = generation
                await task.value
                completeStop(generation: stopGeneration)
            }
        }
    }
    public func stop() async {
        switch lifecycleState {
        case .stopped:
            return
        case .stopping:
            guard let task = shutdownTask else { return }
            let stopGeneration = generation
            await task.value
            completeStop(generation: stopGeneration)
        case .starting, .started:
            beginStop()
            guard let task = shutdownTask else { return }
            let stopGeneration = generation
            await task.value
            completeStop(generation: stopGeneration)
        }
    }

    public func startNewDiagnosticsCapture() async -> Bool {
        await client.startNewDiagnosticsCapture()
    }

    public func stopDiagnosticsCapture() async -> Bool {
        await client.stopDiagnosticsCapture()
    }
    private func completeStart(
        events: AsyncStream<BikeSDKEvent>?,
        generation startGeneration: UInt64
    ) {
        guard lifecycleState == .starting,
              generation == startGeneration
        else { return }

        startupTask = nil
        guard let events else {
            lifecycleState = .stopped
            return
        }

        let targets = LiveBikeRepositoryEventTargets(
            stateStore: stateStore,
            telemetryHub: telemetryHub,
            connectionHub: connectionHub,
            debugHub: debugHub,
            imuHub: imuHub,
            batteryHealthStore: batteryHealthStore,
            batteryHealthHub: batteryHealthHub,
            batteryCaptureHub: batteryCaptureHub,
            discoveredBikesHub: discoveredBikesHub
        )
        eventsTask = Task { [eventHandler, targets] in
            for await event in events {
                guard !Task.isCancelled else { break }
                await eventHandler.handle(event, targets: targets)
            }
        }
        lifecycleState = .started
    }

    private func beginStop() {
        generation &+= 1
        let stopGeneration = generation
        lifecycleState = .stopping

        let startupTask = startupTask
        let eventsTask = eventsTask
        startupTask?.cancel()
        eventsTask?.cancel()

        let client = client
        let eventHandler = eventHandler
        let stateStore = stateStore
        let telemetryHub = telemetryHub
        let connectionHub = connectionHub
        let batteryHealthStore = batteryHealthStore
        let batteryHealthHub = batteryHealthHub
        shutdownTask = Task {
            _ = await startupTask?.value
            await eventsTask?.value
            await client.stop()
            await eventHandler.resetSession()
            let state = await stateStore.resetSession(connectionState: .idle)
            await telemetryHub.send(state.telemetry)
            await connectionHub.send(state.connection)
            await batteryHealthStore.reset()
            await batteryHealthHub.send(BikeBatteryHealth())
        }

        generation = stopGeneration
    }

    private func completeStop(generation stopGeneration: UInt64) {
        guard lifecycleState == .stopping,
              generation == stopGeneration
        else { return }

        startupTask = nil
        eventsTask = nil
        shutdownTask = nil
        lifecycleState = .stopped
    }
}

extension LiveBikeRepository {
    public func connect(vin: String) async throws {
        try await client.connect(to: vin)
    }

    public func startBikeDiscovery() async {
        await client.startBikeDiscovery()
    }

    public func stopBikeDiscovery() async {
        await client.stopBikeDiscovery()
    }

    public func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> {
        await discoveredBikesHub.stream()
    }

    public func disconnect() async throws {
        try await client.disconnect()
    }

    public func retrySecurityHandshake() async throws {
        try await client.retrySecurityHandshake()
    }

    public func readTelemetrySnapshot() async throws {
        try await client.readTelemetrySnapshot()
    }

    public func readBikeStatusSnapshot() async throws {
        try await client.readBikeStatusSnapshot()
    }

    public func readBikeLockFirmwareCompatibility() async throws -> BikeLockFirmwareCompatibility {
        try await controlService.readBikeLockFirmwareCompatibility()
    }

    public func prepareBikeLockControl() async throws -> BikeLockControlSnapshot {
        try await controlService.prepareBikeLockControl()
    }

    public func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        try await controlService.setBikeLocked(isLocked)
    }

    public func refreshPowerModeConfigurations() async throws {
        try await controlService.refreshPowerModeConfigurations()
    }

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await controlService.refreshPowerModeConfiguration(mapIndex: mapIndex)
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
        try await controlService.preparePowerModeControl(mapIndex: mapIndex)
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await controlService.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        try await controlService.prepareTractionControl(mapIndex: mapIndex)
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await controlService.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }

    public func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await controlService.refreshTractionControlConfiguration(mapIndex: mapIndex)
    }

    public func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetryHub.stream(replay: stateStore.currentTelemetry())
    }

    public func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionHub.stream(replay: stateStore.currentConnection())
    }

    public func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        await debugHub.stream()
    }

    public func observeIMU() async -> AsyncStream<BikeIMUSample> {
        await imuHub.stream()
    }

    public func startIMUMonitoring() async throws {
        try await client.startIMUMonitoring()
    }

    public func stopIMUMonitoring() async {
        await client.stopIMUMonitoring()
    }

    public func startBatteryHealthMonitoring() async throws {
        try await client.startBatteryHealthMonitoring()
    }

    public func stopBatteryHealthMonitoring() async {
        await client.stopBatteryHealthMonitoring()
    }

    public func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthHub.stream(replay: batteryHealthStore.currentHealth())
    }

    public func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        await batteryCaptureHub.stream()
    }

    public func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.prepareChargePowerControl(chargingStatus: chargingStatus)
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.setChargePowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        try await controlService.setChargeTarget(percent: percent)
    }
}
