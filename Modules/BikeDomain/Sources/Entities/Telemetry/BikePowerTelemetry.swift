import Foundation

public struct BikePowerTelemetry: Equatable, Sendable {
    public var electricalPowerWatts: Double?
    public var calculatedPowerUpdatedAt: Date?

    public init(
        electricalPowerWatts: Double? = nil,
        calculatedPowerUpdatedAt: Date? = nil
    ) {
        self.electricalPowerWatts = electricalPowerWatts
        self.calculatedPowerUpdatedAt = calculatedPowerUpdatedAt
    }

    public var electricalPowerKilowatts: Double? {
        electricalPowerWatts.map { $0 / 1_000 }
    }

    public var starkMotorPowerHorsepower: Double? {
        electricalPowerWatts.map(BikePowerTelemetryCalculator.starkMotorPowerHorsepower)
    }
}
