import Foundation

public protocol BikeRepository: Sendable {
    func start() async
    func stop() async
    func connect(vin: String) async throws
    func disconnect() async throws
    func retrySecurityHandshake() async throws
    func readTelemetrySnapshot() async throws
    func readBikeStatusSnapshot() async throws
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
    func observeTelemetry() async -> AsyncStream<BikeTelemetry>
    func observeConnection() async -> AsyncStream<BikeConnection>
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent>
}

public extension BikeRepository {
    func readBikeStatusSnapshot() async throws {}
    func refreshPowerModeConfigurations() async throws {}
    func refreshPowerModeConfiguration(mapIndex _: Int) async throws {}
    func preparePowerModeControl(mapIndex _: Int) async throws {
        throw BikeRepositoryError.powerModeControlUnavailable
    }
    func setPowerModeConfiguration(
        mapIndex _: Int,
        horsepower _: Int,
        regenerativeBrakingPercent _: Int
    ) async throws {
        throw BikeRepositoryError.powerModeControlUnavailable
    }
    func prepareTractionControl(mapIndex _: Int) async throws {
        throw BikeRepositoryError.tractionControlUnavailable
    }
    func setTractionControlConfiguration(
        mapIndex _: Int,
        powerTractionPercent _: Double,
        brakingTractionPercent _: Double
    ) async throws {
        throw BikeRepositoryError.tractionControlUnavailable
    }
    func refreshTractionControlConfiguration(mapIndex _: Int) async throws {}
}

private enum BikeRepositoryError: LocalizedError {
    case powerModeControlUnavailable
    case tractionControlUnavailable

    var errorDescription: String? {
        switch self {
        case .powerModeControlUnavailable: "Power mode control is unavailable"
        case .tractionControlUnavailable: "Traction control is unavailable"
        }
    }
}
