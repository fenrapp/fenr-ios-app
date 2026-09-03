import DesignSystem
import SwiftUI

struct RideHistoryMetricRow: View {
    let metric: RideHistoryDetailViewState.Metric

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Constants.accessibilitySpacing) {
                    metricLabel
                    metricValue
                        .padding(.leading, Constants.iconWidth + Constants.spacing)
                }
            } else {
                HStack(spacing: Constants.spacing) {
                    metricLabel
                    Spacer(minLength: Constants.minimumSpacing)
                    metricValue
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var metricLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: Constants.spacing) {
            ListRowIcon(systemImage: metric.symbolName, tint: iconTint)

            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(metric.label)
                    .font(.body)
                if let detail = metric.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var metricValue: some View {
        Text(metric.value)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    private var iconTint: Color {
        switch metric.iconTone {
        case .accent: DesignColor.accent
        case .informational: DesignColor.informational
        case .positive: DesignColor.positive
        }
    }

    private enum Constants {
        static let iconWidth: CGFloat = 32
        static let spacing: CGFloat = 10
        static let textSpacing: CGFloat = 2
        static let minimumSpacing: CGFloat = 8
        static let accessibilitySpacing: CGFloat = 6
    }
}
