import DesignSystem
import SwiftUI

struct BikeLiveActivityMetricStack: View {
    enum Mode {
        case compact
        case regular
    }

    let state: BikeLiveActivityAttributes.ContentState
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
                    .lineLimit(BikeLiveActivityText.singleLineLimit)
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
                        .lineLimit(BikeLiveActivityText.singleLineLimit)
                    Text(metric.value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(BikeLiveActivityText.singleLineLimit)
                        .minimumScaleFactor(Constants.metricMinimumScale)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var metrics: [BikeLiveActivityMetric] {
        optionalMetrics.compactMap { metric in
            metric.value.map { value in
                BikeLiveActivityMetric(title: metric.title, value: value)
            }
        }
    }

    private var optionalMetrics: [OptionalBikeLiveActivityMetric] {
        switch state.mode {
        case .charging:
            [
                OptionalBikeLiveActivityMetric(title: BikeLiveActivityText.power, value: state.powerText),
                OptionalBikeLiveActivityMetric(title: BikeLiveActivityText.current, value: state.currentText),
                OptionalBikeLiveActivityMetric(title: BikeLiveActivityText.temperature, value: state.temperatureText)
            ]
        case .riding, .connectionLost, .stale:
            [
                OptionalBikeLiveActivityMetric(
                    title: BikeLiveActivityText.mode,
                    value: BikeLiveActivityFormatter.modeText(state.modeIndex)
                ),
                OptionalBikeLiveActivityMetric(title: BikeLiveActivityText.speed, value: state.speedText),
                OptionalBikeLiveActivityMetric(title: "State", value: state.runState.displayTitle)
            ]
        }
    }

    private enum Constants {
        static let compactMetricLimit = 2
        static let compactMinimumScale = 0.75
        static let metricMinimumScale = 0.72
    }
}

private struct OptionalBikeLiveActivityMetric {
    let title: String
    let value: String?
}

private struct BikeLiveActivityMetric {
    let title: String
    let value: String
}
