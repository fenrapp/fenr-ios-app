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
        primaryMetrics(telemetry)
            + bmsMetrics(telemetry.positiveBMS, polarity: .positive)
            + bmsMetrics(telemetry.negativeBMS, polarity: .negative)
            + updateMetrics(telemetry)
    }

    private func primaryMetrics(_ telemetry: BikeBatteryTelemetry) -> [BikeDiagnosticsMetricViewData] {
        [
            metric(
                "batterySoc",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricSoc),
                percent(telemetry.stateOfCharge.percent)
            ),
            metric(
                "batterySoh",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricSoh),
                percent(telemetry.stateOfHealth.percent)
            ),
            metric(
                "batteryDcBus",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricBatteryDcBus),
                voltage(telemetry.dcBusVolts, raw: telemetry.dcBusRaw)
            ),
            metric(
                "batteryCurrent",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricBatteryCurrentCandidate),
                current(telemetry.currentCandidateAmperes, raw: telemetry.currentRaw)
            )
        ]
    }

    private func bmsMetrics(
        _ telemetry: BikeBMSSignalsTelemetry?,
        polarity: BMSPolarity
    ) -> [BikeDiagnosticsMetricViewData] {
        [
            bmsVoltageCandidateMetric(polarity.voltageID, polarity.voltageTitle, telemetry),
            bmsMetric(polarity.temperatureID, polarity.temperatureTitle, telemetry, kind: .temperature),
            bmsMetric(polarity.humidityID, polarity.humidityTitle, telemetry, kind: .humidity)
        ]
    }

    private func updateMetrics(_ telemetry: BikeBatteryTelemetry) -> [BikeDiagnosticsMetricViewData] {
        [
            metric(
                "batteryStateUpdated",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricBatteryStateUpdated),
                date(telemetry.stateUpdatedAt)
            ),
            metric(
                "batterySignalsUpdated",
                BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricBatterySignalsUpdated),
                date(telemetry.signalsUpdatedAt)
            )
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

    private func bmsVoltageCandidateMetric(
        _ id: String,
        _ title: String,
        _ telemetry: BikeBMSSignalsTelemetry?
    ) -> BikeDiagnosticsMetricViewData {
        guard let telemetry else { return metric(id, title, BikeDiagnosticsText.placeholder) }
        return metric(id, title, "raw \(telemetry.voltageCandidateRaw)")
    }

    private func date(_ value: Date?) -> String {
        value?.formatted(dateFormatStyle) ?? BikeDiagnosticsText.placeholder
    }

    private enum BMSMetricKind {
        case temperature
        case humidity

        func components(from telemetry: BikeBMSSignalsTelemetry) -> BMSMetricComponents {
            switch self {
            case .temperature:
                .init(value: telemetry.temperatureCelsius, raw: telemetry.temperatureRaw, unit: "C")
            case .humidity:
                .init(value: telemetry.humidityPercent, raw: telemetry.humidityRaw, unit: "%")
            }
        }
    }

    private enum BMSPolarity {
        case positive
        case negative

        var voltageID: String { self == .positive ? "positiveVoltageCandidate" : "negativeVoltageCandidate" }
        var temperatureID: String { self == .positive ? "positiveTemp" : "negativeTemp" }
        var humidityID: String { self == .positive ? "positiveHumidity" : "negativeHumidity" }

        var voltageTitle: String {
            switch self {
            case .positive: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricPositiveBmsVoltage)
            case .negative: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricNegativeBmsVoltage)
            }
        }

        var temperatureTitle: String {
            switch self {
            case .positive: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricPositiveBmsTemperature)
            case .negative: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricNegativeBmsTemperature)
            }
        }

        var humidityTitle: String {
            switch self {
            case .positive: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricPositiveBmsHumidity)
            case .negative: BikeDiagnosticsL10n.text(.bikeDiagnosticsMetricNegativeBmsHumidity)
            }
        }
    }

    private struct BMSMetricComponents {
        let value: Double
        let raw: Int
        let unit: String
    }
}
