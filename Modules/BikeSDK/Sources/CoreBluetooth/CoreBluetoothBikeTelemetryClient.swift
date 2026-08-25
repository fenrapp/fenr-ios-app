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

    public func readTelemetrySnapshot() async throws {
        try await notificationCoordinator.readTelemetrySnapshot()
    }

    public func readBikeStatusSnapshot() async throws {
        try await notificationCoordinator.readBikeStatusSnapshot()
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
