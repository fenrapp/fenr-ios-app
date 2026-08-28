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
            Image(systemName: metric.symbolName)
                .font(.body.weight(.medium))
                .foregroundStyle(.tint)
                .frame(width: Constants.iconWidth)

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
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    private enum Constants {
        static let iconWidth: CGFloat = 24
        static let spacing: CGFloat = 10
        static let textSpacing: CGFloat = 2
        static let minimumSpacing: CGFloat = 8
        static let accessibilitySpacing: CGFloat = 6
    }
}
