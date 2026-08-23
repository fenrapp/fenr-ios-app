import Foundation
import SettingsDomain

public struct RideDashboardMeasurementMapper: Sendable {
    private let measurementSystem: Locale.MeasurementSystem

    public init(measurementSystem: MeasurementSystem = .system, locale: Locale = .autoupdatingCurrent) {
        self.measurementSystem = measurementSystem.resolved(for: locale)
    }

    public init(locale: Locale) {
        self.init(measurementSystem: .system, locale: locale)
    }

    public func speed(kilometersPerHour: Double) -> RideDashboardMeasurement {
        let measurement = Measurement(
            value: kilometersPerHour,
            unit: UnitSpeed.kilometersPerHour
        ).converted(to: speedUnit)
        return RideDashboardMeasurement(value: measurement.value, unit: speedUnit.symbol)
    }

    public func distance(kilometers: Double) -> RideDashboardMeasurement {
        measurement(kilometers, from: .kilometers, to: distanceUnit)
    }

    public func temperature(celsius: Double) -> RideDashboardMeasurement {
        measurement(celsius, from: .celsius, to: temperatureUnit)
    }

    public func power(watts: Double) -> RideDashboardMeasurement {
        measurement(watts, from: UnitPower.watts, to: UnitPower.kilowatts)
    }

    public func current(amperes: Double) -> RideDashboardMeasurement {
        measurement(
            amperes,
            from: UnitElectricCurrent.amperes,
            to: UnitElectricCurrent.amperes
        )
    }

    public func speedometerMaximum() -> RideDashboardMeasurement {
        speed(kilometersPerHour: RideDashboardConstants.maximumSpeedKilometersPerHour)
    }

    private func measurement<Unit>(
        _ value: Double,
        from source: Unit,
        to destination: Unit
    ) -> RideDashboardMeasurement where Unit: Dimension {
        let converted = Measurement(value: value, unit: source).converted(to: destination)
        return RideDashboardMeasurement(value: converted.value, unit: destination.symbol)
    }

    private var speedUnit: UnitSpeed {
        measurementSystem == .metric ? .kilometersPerHour : .milesPerHour
    }

    private var distanceUnit: UnitLength {
        measurementSystem == .metric ? .kilometers : .miles
    }

    private var temperatureUnit: UnitTemperature {
        measurementSystem == .metric ? .celsius : .fahrenheit
    }
}

public struct RideDashboardMeasurement: Sendable, Equatable {
    public let value: Double
    public let unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}
