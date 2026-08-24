import Foundation
import MeasurementPresentation

public struct BikeDiagnosticsSpeedFormatter: Sendable {
    private let measurementMapper: VehicleMeasurementMapper
    private let textFormatter: VehicleMeasurementTextFormatter

    public init(
        measurementSystem: Locale.MeasurementSystem,
        locale: Locale = .autoupdatingCurrent
    ) {
        measurementMapper = VehicleMeasurementMapper(measurementSystem: measurementSystem)
        textFormatter = VehicleMeasurementTextFormatter(locale: locale)
    }

    public func string(kilometersPerHour: Double) -> String {
        textFormatter.string(from: measurementMapper.speed(kilometersPerHour: kilometersPerHour))
    }
}
