import DesignSystem
import SwiftUI

struct DashboardTripStatisticsCard: View {
    let state: DashboardTripStatisticsViewData
    let retryHistory: () -> Void

    var body: some View {
        DashboardAdaptiveCardSurface {
            if state.isLoading {
                ProgressView()
                    .tint(DesignColor.informational)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(.rideDashboardTripStatisticsLoading)
            } else {
                VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
                    if let error = state.historyError {
                        DashboardHistoryReadFeedback(message: error, retry: retryHistory)
                    }
                    if state.showsStatistics { content }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.historyError ?? state.accessibilityLabel)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Constants.sectionSpacing) {
            header
            totalDistance
            Divider()
            metric(state.totalDuration, systemImage: "clock")
            metric(state.averageSpeed, systemImage: "speedometer")
            metric(state.maximumSpeed, systemImage: "arrow.up.right")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        DashboardTripCardHeader(
            title: rideDashboardLocalized(.rideDashboardTripStatisticsTitle),
            subtitle: state.statusText
        )
    }

    private var totalDistance: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSpace.extraExtraSmall) {
            Text(state.totalDistance.valueText)
                .font(.system(size: Constants.heroFontSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DesignColor.primaryText)
            Text(state.totalDistance.unit)
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.totalDistance.label)
        .accessibilityValue(Text(verbatim: "\(state.totalDistance.valueText) \(state.totalDistance.unit)"))
    }

    private func metric(
        _ metric: DashboardTripStatisticsViewData.Metric,
        systemImage: String
    ) -> some View {
        DashboardTripMetricRow(
            label: metric.label,
            valueText: metric.valueText,
            unit: metric.unit,
            systemImage: systemImage
        )
    }

    private enum Constants {
        static let sectionSpacing: CGFloat = 10
        static let heroFontSize: CGFloat = 34
    }
}
