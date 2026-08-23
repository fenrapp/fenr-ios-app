import Foundation

@MainActor
public struct BikeDiagnosticsSpeedFormatter {
    private let measurementSystem: BikeDiagnosticsMeasurementSystem
    private let formatter: MeasurementFormatter

    public init(measurementSystem: BikeDiagnosticsMeasurementSystem, formatter: MeasurementFormatter) {
        self.measurementSystem = measurementSystem
        self.formatter = formatter
    }

    public func string(kilometersPerHour: Double) -> String {
        let measurement = Measurement(value: kilometersPerHour, unit: UnitSpeed.kilometersPerHour)
        return formatter.string(from: measurement.converted(to: displayUnit))
    }

    private var displayUnit: UnitSpeed {
        switch measurementSystem {
        case .metric: .kilometersPerHour
        case .imperial: .milesPerHour
        }
    }

}
