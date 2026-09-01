import DesignSystem
import SwiftUI

struct BikeLiveActivityMetricStack: View {
    enum Mode {
        case compact
        case regular
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    .lineLimit(accessibilityLineLimit)
                    .minimumScaleFactor(Constants.compactMinimumScale)
                    .fixedSize(horizontal: false, vertical: usesAccessibilityLayout)
                    .accessibilityLabel("\(metric.title), \(metric.value)")
            }
        }
    }

    private var regularMetrics: some View {
        Group {
            if usesAccessibilityLayout {
                VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                    ForEach(metrics, id: \.title) { metric in
                        metricView(metric)
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraSmall) {
                    ForEach(metrics, id: \.title) { metric in
                        metricView(metric)
                    }
                }
            }
        }
    }

    private func metricView(_ metric: BikeLiveActivityMetric) -> some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text(metric.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(DesignColor.secondaryText)
                .lineLimit(accessibilityLineLimit)
            Text(metric.value)
                .font(.caption.weight(.semibold))
                .lineLimit(accessibilityLineLimit)
                .minimumScaleFactor(Constants.metricMinimumScale)
                .monospacedDigit()
        }
        .fixedSize(horizontal: false, vertical: usesAccessibilityLayout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var accessibilityLineLimit: Int? {
        usesAccessibilityLayout ? nil : BikeLiveActivityText.singleLineLimit
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
