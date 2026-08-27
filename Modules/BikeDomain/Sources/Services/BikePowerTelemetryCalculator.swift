public struct BikePowerTelemetryCalculation: Equatable, Sendable {
    public let electricalPowerWatts: Double

    public init(electricalPowerWatts: Double) {
        self.electricalPowerWatts = electricalPowerWatts
    }

    public var starkMotorPowerHorsepower: Double {
        BikePowerTelemetryCalculator.starkMotorPowerHorsepower(electricalPowerWatts)
    }
}

public struct BikePowerTelemetryCalculator: Sendable {
    public init() {}

    public func calculate(
        dcBusVolts: Double,
        batteryCurrentCandidateAmperes: Double
    ) -> BikePowerTelemetryCalculation {
        let electricalPowerWatts = dcBusVolts * batteryCurrentCandidateAmperes
        return BikePowerTelemetryCalculation(electricalPowerWatts: electricalPowerWatts)
    }

    static func starkMotorPowerHorsepower(_ electricalPowerWatts: Double) -> Double {
        electricalPowerWatts * Constants.starkHorsepowerFactor
    }

    private enum Constants {
        static let starkHorsepowerFactor = 0.0011
    }
}
