import BikeDomain
import Foundation
import MeasurementPresentation

@MainActor
public struct BikeBatteryTelemetryToMetricsMapper {
    private let dateFormatStyle: Date.FormatStyle
    private let measurementTextFormatter: VehicleMeasurementTextFormatter

    public init(
        dateFormatStyle: Date.FormatStyle,
        measurementTextFormatter: VehicleMeasurementTextFormatter
    ) {
        self.dateFormatStyle = dateFormatStyle
        self.measurementTextFormatter = measurementTextFormatter
    }

    public func map(_ telemetry: BikeBatteryTelemetry) -> [BikeDiagnosticsMetricViewData] {
        [
            metric("batterySoc", "SOC", percent(telemetry.stateOfCharge.percent)),
            metric("batterySoh", "SOH", percent(telemetry.stateOfHealth.percent)),
            metric(
                "batteryDcBus",
                "Battery DC bus",
                voltage(telemetry.dcBusVolts, raw: telemetry.dcBusRaw)
            ),
            metric(
                "batteryCurrent",
                "Battery current",
                current(telemetry.currentAmperes, raw: telemetry.currentRaw)
            ),
            bmsMetric("positiveBus", "Positive BMS DC bus", telemetry.positiveBMS, kind: .dcBus),
            bmsMetric(
                "positiveTemp",
                "Positive BMS temperature",
                telemetry.positiveBMS,
                kind: .temperature
            ),
            bmsMetric(
                "positiveHumidity",
                "Positive BMS humidity",
                telemetry.positiveBMS,
                kind: .humidity
            ),
            bmsMetric("negativeBus", "Negative BMS DC bus", telemetry.negativeBMS, kind: .dcBus),
            bmsMetric(
                "negativeTemp",
                "Negative BMS temperature",
                telemetry.negativeBMS,
                kind: .temperature
            ),
            bmsMetric(
                "negativeHumidity",
                "Negative BMS humidity",
                telemetry.negativeBMS,
                kind: .humidity
            ),
            metric("batteryStateUpdated", "Battery state updated", date(telemetry.stateUpdatedAt)),
            metric("batterySignalsUpdated", "Battery signals updated", date(telemetry.signalsUpdatedAt))
        ]
    }

    private func metric(_ id: String, _ title: String, _ value: String) -> BikeDiagnosticsMetricViewData {
        .init(id: id, title: title, value: value)
    }

    private func percent(_ value: Int?) -> String {
        value.map { measurementTextFormatter.percentage($0) } ?? BikeDiagnosticsText.placeholder
    }

    private func voltage(_ value: Double?, raw: Int?) -> String {
        guard let value, let raw else { return BikeDiagnosticsText.placeholder }
        return "\(measurementTextFormatter.voltage(value)) (raw \(raw))"
    }

    private func current(_ value: Double?, raw: Int?) -> String {
        guard let value, let raw else { return BikeDiagnosticsText.placeholder }
        return "\(measurementTextFormatter.current(value)) (raw \(raw))"
    }

    private func bmsMetric(
        _ id: String,
        _ title: String,
        _ telemetry: BikeBMSSignalsTelemetry?,
        kind: BMSMetricKind
    ) -> BikeDiagnosticsMetricViewData {
        guard let telemetry else { return metric(id, title, BikeDiagnosticsText.placeholder) }
        let components = kind.components(from: telemetry)
        let valueText = measurementTextFormatter.number(
            components.value,
            fractionDigits: 2
        )
        return metric(
            id,
            title,
            "\(valueText) \(components.unit) (raw \(components.raw))"
        )
    }

    private func date(_ value: Date?) -> String {
        value?.formatted(dateFormatStyle) ?? BikeDiagnosticsText.placeholder
    }

    private enum BMSMetricKind {
        case dcBus
        case temperature
        case humidity

        func components(from telemetry: BikeBMSSignalsTelemetry) -> BMSMetricComponents {
            switch self {
            case .dcBus: .init(value: telemetry.dcBusVolts, raw: telemetry.dcBusRaw, unit: "V")
            case .temperature:
                .init(value: telemetry.temperatureCelsius, raw: telemetry.temperatureRaw, unit: "C")
            case .humidity:
                .init(value: telemetry.humidityPercent, raw: telemetry.humidityRaw, unit: "%")
            }
        }
    }

    private struct BMSMetricComponents {
        let value: Double
        let raw: Int
        let unit: String
    }
}
