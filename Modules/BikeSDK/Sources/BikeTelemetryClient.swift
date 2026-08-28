public protocol BikeTelemetryClient: AnyObject, Sendable {
    func start() async
    func stop() async
    func connect(to vin: String) async throws
    func startBikeDiscovery() async
    func stopBikeDiscovery() async
    func disconnect() async throws
    func retrySecurityHandshake() async throws
    func readTelemetrySnapshot() async throws
    func readBikeStatusSnapshot() async throws
    func startBatteryHealthMonitoring() async throws
    func stopBatteryHealthMonitoring() async
    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot
    func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot
    func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot
    func refreshPowerModeConfigurations() async throws
    func refreshPowerModeConfiguration(mapIndex: Int) async throws
    func refreshTractionControlConfiguration(mapIndex: Int) async throws
    func events() async -> AsyncStream<BikeSDKEvent>
}

public extension BikeTelemetryClient {
    func readBikeStatusSnapshot() async throws {}
    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot {
        throw BikeSDKError.operationFailed("Charge power control is unavailable")
    }
    func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        throw BikeSDKError.operationFailed("Charge power control is unavailable")
    }
    func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot {
        throw BikeSDKError.operationFailed("Charge target control is unavailable")
    }
    func refreshPowerModeConfigurations() async throws {
        throw BikeSDKError.operationFailed("Power mode configuration refresh is unavailable")
    }
    func refreshPowerModeConfiguration(mapIndex _: Int) async throws {
        throw BikeSDKError.operationFailed("Power mode configuration refresh is unavailable")
    }
    func refreshTractionControlConfiguration(mapIndex _: Int) async throws {
        throw BikeSDKError.operationFailed("Traction control configuration refresh is unavailable")
    }
}
