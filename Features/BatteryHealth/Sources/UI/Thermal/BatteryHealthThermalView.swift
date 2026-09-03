import DesignSystem
import SwiftUI

struct BatteryHealthThermalView: View {
    let state: BatteryHealthThermalViewData

    var body: some View {
        List {
            Section(BatteryHealthText.temperatureRange) {
                if state.metrics.isEmpty {
                    ContentUnavailableView(
                        BatteryHealthText.awaitingTemperatures,
                        systemImage: "thermometer.medium",
                        description: Text(BatteryHealthText.awaitingTemperaturesDetail)
                    )
                } else {
                    BatteryHealthMetricRows(metrics: state.metrics)
                    temperatureRangeGauge
                }
            }

            Section(BatteryHealthText.sensors) {
                if state.sensors.isEmpty {
                    Text(BatteryHealthText.noDecodedSensors)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.sensors) { sensor in
                        LabeledContent(BatteryHealthText.sensorPosition(sensor.position)) {
                            HStack {
                                Image(systemName: symbol(for: sensor.emphasis))
                                    .foregroundStyle(color(for: sensor.emphasis))
                                    .accessibilityHidden(true)
                                Text(sensor.value)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var temperatureRangeGauge: some View {
        if let valueRange = state.valueRangeCelsius,
           let average = state.averageCelsius,
           let domain = state.displayDomainCelsius {
            VStack(spacing: DesignSpace.extraSmall) {
                RangeGauge(
                    valueRange: valueRange,
                    average: average,
                    domain: domain,
                    markerColor: color(for: state.emphasis)
                )
                HStack {
                    Text(state.metrics.first?.value ?? BatteryHealthText.placeholder)
                    Spacer()
                    Text(state.metrics.last?.value ?? BatteryHealthText.placeholder)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: BatteryHealthText.temperatureRangeAccessibility))
            .accessibilityValue(state.metrics.map { "\($0.title) \($0.value)" }.joined(separator: ", "))
        }
    }

    private func symbol(for emphasis: BatteryHealthStatusEmphasis) -> String {
        switch emphasis {
        case .neutral: "minus.circle"
        case .positive: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .critical: "exclamationmark.octagon"
        }
    }

    private func color(for emphasis: BatteryHealthStatusEmphasis) -> Color {
        switch emphasis {
        case .neutral: .secondary
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }
}
