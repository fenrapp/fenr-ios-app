import MeasurementPresentation

public struct RideDashboardMeasurementMapper: Sendable {
    private let measurementMapper: VehicleMeasurementMapper
    private let textFormatter: VehicleMeasurementTextFormatter

    public init(
        measurementMapper: VehicleMeasurementMapper,
        textFormatter: VehicleMeasurementTextFormatter
    ) {
        self.measurementMapper = measurementMapper
        self.textFormatter = textFormatter
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

    public func number(
        _ value: Double,
        fractionDigits: Int
    ) -> String {
        textFormatter.number(value, fractionDigits: fractionDigits)
    }

    public func metric(
        _ measurement: RideDashboardMeasurement?,
        fractionDigits: Int
    ) -> DashboardMetricViewData {
        guard let measurement else { return .init() }
        return .init(
            valueText: textFormatter.number(measurement.value, fractionDigits: fractionDigits),
            unitText: measurement.unit,
            animationValue: measurement.value
        )
    }
}

public typealias RideDashboardMeasurement = VehicleMeasurement
