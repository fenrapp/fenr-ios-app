import RuntimeConfiguration

@MainActor
public final class CoreBluetoothBikeTelemetryClient: BikeTelemetryClient {
    private let eventHub: AsyncEventHub<BikeSDKEvent>
    private let adapter: CoreBluetoothAdapter
    private let callbackQueue: BikeBLECallbackQueue
    private let connectionCoordinator: BikeBLEConnectionCoordinator
    private let securityCoordinator: BikeBLESecurityCoordinator
    private let notificationCoordinator: BikeBLENotificationCoordinator
    private let centralDelegate: CoreBluetoothCentralDelegateProxy
    private let centralRestorationIdentifier: String?
    private var isCentralStarted = false

    public init(
        eventHub: AsyncEventHub<BikeSDKEvent>,
        adapter: CoreBluetoothAdapter,
        callbackQueue: BikeBLECallbackQueue,
        connectionCoordinator: BikeBLEConnectionCoordinator,
        securityCoordinator: BikeBLESecurityCoordinator,
        notificationCoordinator: BikeBLENotificationCoordinator,
        centralDelegate: CoreBluetoothCentralDelegateProxy,
        centralRestorationIdentifier: String?
    ) {
        self.eventHub = eventHub
        self.adapter = adapter
        self.callbackQueue = callbackQueue
        self.connectionCoordinator = connectionCoordinator
        self.securityCoordinator = securityCoordinator
        self.notificationCoordinator = notificationCoordinator
        self.centralDelegate = centralDelegate
        self.centralRestorationIdentifier = centralRestorationIdentifier
    }

    nonisolated public func events() async -> AsyncStream<BikeSDKEvent> {
        await eventHub.stream()
    }

    public func start() async {
        startRuntimeIfNeeded()
    }

    public func stop() async {
        callbackQueue.cancelPending()
        await connectionCoordinator.stop()
    }

    public func connect(to vin: String) async throws {
        startRuntimeIfNeeded()
        try await connectionCoordinator.connect(to: vin)
    }

    public func startBikeDiscovery() async {
        startRuntimeIfNeeded()
        await connectionCoordinator.startBikeDiscovery()
    }

    public func stopBikeDiscovery() async {
        await connectionCoordinator.stopBikeDiscovery()
    }

    public func disconnect() async throws {
        try await connectionCoordinator.disconnect()
    }

    public func retrySecurityHandshake() async throws {
        try await securityCoordinator.retry()
    }

    public func startNewDiagnosticsCapture(vin: String) async -> Bool {
        await connectionCoordinator.startNewDiagnosticsCapture(vin: vin)
    }

    public func stopDiagnosticsCapture() async -> Bool {
        await connectionCoordinator.stopDiagnosticsCapture()
    }

    public func readTelemetrySnapshot() async throws {
        try await notificationCoordinator.readTelemetrySnapshot()
    }

    public func readBikeStatusSnapshot() async throws {
        try await notificationCoordinator.readBikeStatusSnapshot()
    }

    public func startIMUMonitoring() async throws {
        try await notificationCoordinator.startIMUMonitoring()
    }

    public func stopIMUMonitoring() async {
        await notificationCoordinator.stopIMUMonitoring()
    }

    public func startBatteryHealthMonitoring() async throws {
        try await notificationCoordinator.startBatteryHealthMonitoring()
    }

    public func stopBatteryHealthMonitoring() async {
        await notificationCoordinator.stopBatteryHealthMonitoring()
    }

    public func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        try await notificationCoordinator.prepareChargePowerControl(context: context)
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        try await notificationCoordinator.setChargePowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        try await notificationCoordinator.setChargeTarget(percent: percent)
    }

    public func readBikeLockFirmwareCompatibility() async throws -> BikeSDKBikeLockFirmwareCompatibility {
        try await notificationCoordinator.readBikeLockFirmwareCompatibility()
    }

    public func prepareBikeLockControl() async throws -> BikeSDKBikeLockControlSnapshot {
        try await notificationCoordinator.prepareBikeLockControl()
    }

    public func setBikeLocked(_ isLocked: Bool) async throws -> BikeSDKBikeLockControlSnapshot {
        try await notificationCoordinator.setBikeLocked(isLocked)
    }

    public func refreshPowerModeConfigurations() async throws {
        try await notificationCoordinator.refreshPowerModeConfigurations()
    }

    public func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await notificationCoordinator.refreshPowerModeConfiguration(mapIndex: mapIndex)
    }

    public func preparePowerModeControl(mapIndex: Int) async throws {
        try await notificationCoordinator.preparePowerModeControl(mapIndex: mapIndex)
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await notificationCoordinator.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
    }

    public func readTractionControlFirmwareCompatibility() async throws -> BikeSDKTractionControlFirmwareCompatibility {
        try await notificationCoordinator.readTractionControlFirmwareCompatibility()
    }

    public func applyUserTractionControlConfiguration(
        mapIndex: Int, powerTractionPercent: Double, brakingTractionPercent: Double,
        expected: BikeSDKTractionControlSnapshot?
    ) async throws -> BikeSDKTractionControlSnapshot {
        try await notificationCoordinator.applyUserTractionControlConfiguration(
            mapIndex: mapIndex, powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent, expected: expected
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        try await notificationCoordinator.prepareTractionControl(mapIndex: mapIndex)
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await notificationCoordinator.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }

    public func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await notificationCoordinator.refreshTractionControlConfiguration(mapIndex: mapIndex)
    }

    private func startRuntimeIfNeeded() {
        callbackQueue.start()
        guard !isCentralStarted else { return }
        adapter.start(
            delegate: centralDelegate,
            restorationIdentifier: centralRestorationIdentifier
        )
        isCentralStarted = true
    }
}

extension CoreBluetoothBikeTelemetryClient {
    public func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        try await notificationCoordinator.readAdvancedPowerMode(mapIndex: mapIndex)
    }
    public func applyAdvancedPowerMode(
        expected: BikeSDKAdvancedPowerModeConfiguration,
        desired: BikeSDKAdvancedPowerModeConfiguration
    ) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        try await notificationCoordinator.applyAdvancedPowerMode(expected: expected, desired: desired)
    }
}

extension CoreBluetoothBikeTelemetryClient {
    public func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        try await notificationCoordinator.applyBasicPowerMode(
            mapIndex: mapIndex, horsepower: horsepower, regeneration: regeneration
        )
    }
}
