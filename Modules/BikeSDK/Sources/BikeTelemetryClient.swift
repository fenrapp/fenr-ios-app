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
    func startIMUMonitoring() async throws
    func stopIMUMonitoring() async
    func startBatteryHealthMonitoring() async throws
    func stopBatteryHealthMonitoring() async
    func prepareChargePowerControl(
        context: BikeSDKChargePowerTelemetryContext
    ) async throws -> BikeSDKChargePowerControlSnapshot
    func setChargePowerLimit(watts: Int) async throws -> BikeSDKChargePowerControlSnapshot
    func setChargeTarget(percent: Int) async throws -> BikeSDKChargePowerControlSnapshot
    func prepareBikeLockControl() async throws -> BikeSDKBikeLockControlSnapshot
    func setBikeLocked(_ isLocked: Bool) async throws -> BikeSDKBikeLockControlSnapshot
    func refreshPowerModeConfigurations() async throws
    func refreshPowerModeConfiguration(mapIndex: Int) async throws
    func preparePowerModeControl(mapIndex: Int) async throws
    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws
    func prepareTractionControl(mapIndex: Int) async throws
    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws
    func refreshTractionControlConfiguration(mapIndex: Int) async throws
    func events() async -> AsyncStream<BikeSDKEvent>
}

public extension BikeTelemetryClient {
    func readBikeStatusSnapshot() async throws {}
    func startIMUMonitoring() async throws {}
    func stopIMUMonitoring() async {}
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
    func prepareBikeLockControl() async throws -> BikeSDKBikeLockControlSnapshot {
        throw BikeSDKError.operationFailed("Bike Lock control is unavailable")
    }
    func setBikeLocked(_ isLocked: Bool) async throws -> BikeSDKBikeLockControlSnapshot {
        throw BikeSDKError.operationFailed("Bike Lock control is unavailable")
    }
    func refreshPowerModeConfigurations() async throws {
        throw BikeSDKError.operationFailed("Power mode configuration refresh is unavailable")
    }
    func refreshPowerModeConfiguration(mapIndex _: Int) async throws {
        throw BikeSDKError.operationFailed("Power mode configuration refresh is unavailable")
    }
    func preparePowerModeControl(mapIndex _: Int) async throws {
        throw BikeSDKError.operationFailed("Power mode control is unavailable")
    }
    func setPowerModeConfiguration(
        mapIndex _: Int,
        horsepower _: Int,
        regenerativeBrakingPercent _: Int
    ) async throws {
        throw BikeSDKError.operationFailed("Power mode control is unavailable")
    }
    func prepareTractionControl(mapIndex _: Int) async throws {
        throw BikeSDKError.operationFailed("Traction control is unavailable")
    }
    func setTractionControlConfiguration(
        mapIndex _: Int,
        powerTractionPercent _: Double,
        brakingTractionPercent _: Double
    ) async throws {
        throw BikeSDKError.operationFailed("Traction control is unavailable")
    }
    func refreshTractionControlConfiguration(mapIndex _: Int) async throws {
        throw BikeSDKError.operationFailed("Traction control configuration refresh is unavailable")
    }
}
