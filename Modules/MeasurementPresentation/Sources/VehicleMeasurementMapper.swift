import Foundation

public struct VehicleMeasurementMapper: Sendable {
    private let measurementSystem: Locale.MeasurementSystem

    public init(
        measurementSystem: Locale.MeasurementSystem = Locale.autoupdatingCurrent.measurementSystem
    ) {
        self.measurementSystem = measurementSystem
    }

    public func speed(kilometersPerHour: Double) -> VehicleMeasurement {
        measurement(kilometersPerHour, from: .kilometersPerHour, to: speedUnit)
    }

    public func distance(kilometers: Double) -> VehicleMeasurement {
        measurement(kilometers, from: .kilometers, to: distanceUnit)
    }

    public func temperature(celsius: Double) -> VehicleMeasurement {
        measurement(celsius, from: .celsius, to: temperatureUnit)
    }

    public func power(watts: Double) -> VehicleMeasurement {
        measurement(watts, from: UnitPower.watts, to: UnitPower.kilowatts)
    }

    public func current(amperes: Double) -> VehicleMeasurement {
        measurement(
            amperes,
            from: UnitElectricCurrent.amperes,
            to: UnitElectricCurrent.amperes
        )
    }

    private func measurement<Unit>(
        _ value: Double,
        from source: Unit,
        to destination: Unit
    ) -> VehicleMeasurement where Unit: Dimension {
        let converted = Measurement(value: value, unit: source).converted(to: destination)
        return VehicleMeasurement(value: converted.value, unit: destination.symbol)
    }

    private var speedUnit: UnitSpeed {
        measurementSystem == .metric ? .kilometersPerHour : .milesPerHour
    }

    private var distanceUnit: UnitLength {
        measurementSystem == .metric ? .kilometers : .miles
    }

    private var temperatureUnit: UnitTemperature {
        measurementSystem == .us ? .fahrenheit : .celsius
    }
}
