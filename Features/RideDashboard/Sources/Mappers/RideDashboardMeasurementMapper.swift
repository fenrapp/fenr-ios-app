import Foundation
import MeasurementPresentation
import SettingsDomain

public struct RideDashboardMeasurementMapper: Sendable {
    private let measurementMapper: VehicleMeasurementMapper

    public init(measurementSystem: MeasurementSystem = .system, locale: Locale = .autoupdatingCurrent) {
        measurementMapper = VehicleMeasurementMapper(
            measurementSystem: measurementSystem.resolved(for: locale)
        )
    }

    public init(locale: Locale) {
        self.init(measurementSystem: .system, locale: locale)
    }

    public func speed(kilometersPerHour: Double) -> RideDashboardMeasurement {
        measurementMapper.speed(kilometersPerHour: kilometersPerHour)
    }

    public func distance(kilometers: Double) -> RideDashboardMeasurement {
        measurementMapper.distance(kilometers: kilometers)
    }

    public func temperature(celsius: Double) -> RideDashboardMeasurement {
        measurementMapper.temperature(celsius: celsius)
    }

    public func power(watts: Double) -> RideDashboardMeasurement {
        measurementMapper.power(watts: watts)
    }

    public func current(amperes: Double) -> RideDashboardMeasurement {
        measurementMapper.current(amperes: amperes)
    }

    public func speedometerMaximum() -> RideDashboardMeasurement {
        speed(kilometersPerHour: RideDashboardConstants.maximumSpeedKilometersPerHour)
    }

}

public typealias RideDashboardMeasurement = VehicleMeasurement
