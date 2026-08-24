import DesignSystem
import SwiftUI

struct ChargingLiveActivityMetricStack: View {
    enum Mode {
        case compact
        case regular
    }

    let state: ChargingLiveActivityAttributes.ContentState
    let mode: Mode

    var body: some View {
        switch mode {
        case .compact:
            compactMetrics
        case .regular:
            regularMetrics
        }
    }

    private var compactMetrics: some View {
        VStack(alignment: .trailing, spacing: DesignSpace.extraExtraSmall) {
            ForEach(metrics.prefix(Constants.compactMetricLimit), id: \.title) { metric in
                Text(metric.value)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(ChargingLiveActivityText.singleLineLimit)
                    .minimumScaleFactor(Constants.compactMinimumScale)
            }
        }
    }

    private var regularMetrics: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
            ForEach(metrics, id: \.title) { metric in
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(metric.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(DesignColor.secondaryText)
                        .lineLimit(ChargingLiveActivityText.singleLineLimit)
                    Text(metric.value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(ChargingLiveActivityText.singleLineLimit)
                        .minimumScaleFactor(Constants.metricMinimumScale)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metrics: [ChargingLiveActivityMetric] {
        [
            OptionalChargingLiveActivityMetric(title: ChargingLiveActivityText.power, value: state.powerText),
            OptionalChargingLiveActivityMetric(title: ChargingLiveActivityText.current, value: state.currentText),
            OptionalChargingLiveActivityMetric(title: ChargingLiveActivityText.temperature, value: state.temperatureText)
        ].compactMap { metric in
            metric.value.map { value in
                ChargingLiveActivityMetric(title: metric.title, value: value)
            }
        }
    }

    private enum Constants {
        static let compactMetricLimit = 2
        static let compactMinimumScale = 0.75
        static let metricMinimumScale = 0.72
    }
}

private struct OptionalChargingLiveActivityMetric {
    let title: String
    let value: String?
}

private struct ChargingLiveActivityMetric {
    let title: String
    let value: String
}
