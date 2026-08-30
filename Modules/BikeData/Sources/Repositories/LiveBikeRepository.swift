import BikeDomain
import BikeSDK
import Foundation

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
    private let chargePowerMapper: BikeSDKChargePowerControlToDomainMapper
    private var task: Task<Void, Never>?

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
        chargePowerMapper: BikeSDKChargePowerControlToDomainMapper
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
        self.chargePowerMapper = chargePowerMapper
        self.eventHandler = eventHandler
    }

    deinit {
        task?.cancel()
    }

    public func start() async {
        guard task == nil else { return }
        await client.start()
        let events = await client.events()
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
        task = Task { [eventHandler, targets] in
            for await event in events {
                await eventHandler.handle(event, targets: targets)
            }
        }
    }

    public func stop() async {
        task?.cancel()
        task = nil
        await client.stop()
        let state = await stateStore.resetSession(connectionState: .idle)
        await telemetryHub.send(state.telemetry)
        await connectionHub.send(state.connection)
        await batteryHealthStore.reset()
        await batteryHealthHub.send(BikeBatteryHealth())
    }

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

    public func prepareBikeLockControl() async throws -> BikeLockControlSnapshot {
        let snapshot = try await client.prepareBikeLockControl()
        return .init(
            vcuFirmware: snapshot.vcuFirmware,
            isLocked: snapshot.isLocked,
            didPassNoOpWrite: snapshot.didPassNoOpWrite
        )
    }

    public func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        let snapshot = try await client.setBikeLocked(isLocked)
        return .init(
            vcuFirmware: snapshot.vcuFirmware,
            isLocked: snapshot.isLocked,
            didPassNoOpWrite: snapshot.didPassNoOpWrite
        )
    }

    public func refreshPowerModeConfigurations() async throws {
        try await client.refreshPowerModeConfigurations()
    }

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await client.refreshPowerModeConfiguration(mapIndex: mapIndex)
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
        try await client.preparePowerModeControl(mapIndex: mapIndex)
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await client.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        try await client.prepareTractionControl(mapIndex: mapIndex)
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await client.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }

    public func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await client.refreshTractionControlConfiguration(mapIndex: mapIndex)
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
        let snapshot = try await client.prepareChargePowerControl(
            context: .init(
                requestedCurrentAmperes: chargingStatus.requestedCurrentAmperes,
                maximumCurrentAmperes: chargingStatus.maximumCurrentAmperes,
                maximumPowerWatts: chargingStatus.maximumPowerWatts,
                maximumStateOfChargePercent: chargingStatus.maximumStateOfChargePercent,
                chargerTypeRaw: chargingStatus.chargerType.rawValue
            )
        )
        return chargePowerMapper.map(snapshot)
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        let snapshot = try await client.setChargePowerLimit(watts: watts)
        return chargePowerMapper.map(snapshot)
    }

    public func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        let snapshot = try await client.setChargeTarget(percent: percent)
        return chargePowerMapper.map(snapshot)
    }
}
