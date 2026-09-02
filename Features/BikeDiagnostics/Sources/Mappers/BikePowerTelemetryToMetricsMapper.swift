import BikeDomain
import Foundation
import MeasurementPresentation

@MainActor
public struct BikePowerTelemetryToMetricsMapper {
    private let dateFormatStyle: Date.FormatStyle
    private let measurementTextFormatter: VehicleMeasurementTextFormatter

    public init(
        dateFormatStyle: Date.FormatStyle,
        measurementTextFormatter: VehicleMeasurementTextFormatter
    ) {
        self.dateFormatStyle = dateFormatStyle
        self.measurementTextFormatter = measurementTextFormatter
    }

    public func map(_ telemetry: BikePowerTelemetry) -> [BikeDiagnosticsMetricViewData] {
        [
            metric(
                "electricalPower",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricElectricalPower),
                power(watts: telemetry.electricalPowerWatts, kilowatts: telemetry.electricalPowerKilowatts)
            ),
            metric(
                "starkHorsepower",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricStarkPower),
                horsepower(telemetry.starkMotorPowerHorsepower)
            ),
            metric(
                "calculatedPowerUpdated",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricPowerUpdated),
                date(telemetry.calculatedPowerUpdatedAt)
            )
        ]
    }

    private func metric(_ id: String, _ title: String, _ value: String) -> BikeDiagnosticsMetricViewData {
        .init(id: id, title: title, value: value)
    }

    private func power(watts value: Double?, kilowatts: Double?) -> String {
        guard let value, let kilowatts else { return BikeDiagnosticsText.placeholder }
        let watts = measurementTextFormatter.number(value, fractionDigits: 1)
        let kilowattsText = measurementTextFormatter.number(kilowatts, fractionDigits: 3)
        return "\(watts) W / \(kilowattsText) kW"
    }

    private func horsepower(_ value: Double?) -> String {
        guard let value else { return BikeDiagnosticsText.placeholder }
        return "\(measurementTextFormatter.number(value, fractionDigits: 2)) hp"
    }

    private func date(_ value: Date?) -> String {
        value?.formatted(dateFormatStyle) ?? BikeDiagnosticsText.placeholder
    }
}
