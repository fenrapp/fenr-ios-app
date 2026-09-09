import Foundation

public protocol BikeControlRepository: Sendable {
    var supportsAdvancedPowerModes: Bool { get }
    func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeAdvancedPowerModeConfiguration
    func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeAdvancedPowerModeConfiguration
    func applyAdvancedPowerMode(
        expected: BikeAdvancedPowerModeConfiguration,
        desired: BikeAdvancedPowerModeConfiguration
    ) async throws -> BikeAdvancedPowerModeConfiguration
    func readBikeLockFirmwareCompatibility() async throws -> BikeLockFirmwareCompatibility
    func prepareBikeLockControl() async throws -> BikeLockControlSnapshot
    func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot
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
}

public extension BikeControlRepository {
    var supportsAdvancedPowerModes: Bool { false }
    func readBikeLockFirmwareCompatibility() async throws -> BikeLockFirmwareCompatibility {
        throw BikeControlRepositoryError.bikeLockControlUnavailable
    }

    func prepareBikeLockControl() async throws -> BikeLockControlSnapshot {
        throw BikeControlRepositoryError.bikeLockControlUnavailable
    }

    func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        throw BikeControlRepositoryError.bikeLockControlUnavailable
    }

    func refreshPowerModeConfigurations() async throws {}

    func refreshPowerModeConfiguration(mapIndex _: Int) async throws {}

    func preparePowerModeControl(mapIndex _: Int) async throws {
        throw BikeControlRepositoryError.powerModeControlUnavailable
    }

    func setPowerModeConfiguration(
        mapIndex _: Int,
        horsepower _: Int,
        regenerativeBrakingPercent _: Int
    ) async throws {
        throw BikeControlRepositoryError.powerModeControlUnavailable
    }

    func prepareTractionControl(mapIndex _: Int) async throws {
        throw BikeControlRepositoryError.tractionControlUnavailable
    }

    func setTractionControlConfiguration(
        mapIndex _: Int,
        powerTractionPercent _: Double,
        brakingTractionPercent _: Double
    ) async throws {
        throw BikeControlRepositoryError.tractionControlUnavailable
    }

    func refreshTractionControlConfiguration(mapIndex _: Int) async throws {}

    func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeAdvancedPowerModeConfiguration {
        throw BikeControlRepositoryError.powerModeControlUnavailable
    }
    func applyAdvancedPowerMode(
        expected: BikeAdvancedPowerModeConfiguration,
        desired: BikeAdvancedPowerModeConfiguration
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        throw BikeControlRepositoryError.powerModeControlUnavailable
    }
    func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        throw BikeControlRepositoryError.powerModeControlUnavailable
    }
}

public enum BikeControlRepositoryError: LocalizedError, Equatable, Sendable {
    case powerModeControlUnavailable
    case tractionControlUnavailable
    case bikeLockControlUnavailable

    public var errorDescription: String? {
        switch self {
        case .powerModeControlUnavailable: "Power mode control is unavailable"
        case .tractionControlUnavailable: "Traction control is unavailable"
        case .bikeLockControlUnavailable: "Bike Lock control is unavailable"
        }
    }
}
