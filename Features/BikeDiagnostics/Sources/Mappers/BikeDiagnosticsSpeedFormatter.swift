import Foundation
import MeasurementPresentation

public struct BikeDiagnosticsSpeedFormatter: Sendable {
    private let measurementMapper: VehicleMeasurementMapper
    private let textFormatter: VehicleMeasurementTextFormatter

    public init(
        measurementMapper: VehicleMeasurementMapper,
        textFormatter: VehicleMeasurementTextFormatter
    ) {
        self.measurementMapper = measurementMapper
        self.textFormatter = textFormatter
    }

    public func string(kilometersPerHour: Double) -> String {
        textFormatter.string(from: measurementMapper.speed(kilometersPerHour: kilometersPerHour))
    }

    public func distance(kilometers: Double) -> String {
        textFormatter.string(from: measurementMapper.distance(kilometers: kilometers))
    }

    public func temperature(celsius: Double) -> String {
        textFormatter.string(from: measurementMapper.temperature(celsius: celsius))
    }
}
