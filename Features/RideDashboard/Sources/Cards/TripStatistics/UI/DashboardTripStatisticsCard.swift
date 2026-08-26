import DesignSystem
import SwiftUI

struct DashboardTripStatisticsCard: View {
    let state: DashboardTripStatisticsViewData

    var body: some View {
        DashboardTripCardSurface {
            if state.isLoading {
                ProgressView()
                    .tint(DesignColor.informational)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading ride statistics")
            } else {
                content
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
    }

    private var content: some View {
        VStack(spacing: Constants.sectionSpacing) {
            header
            totalDistance
            Divider()
            metric(state.totalDuration, systemImage: "clock")
            metric(state.averageSpeed, systemImage: "speedometer")
            metric(state.maximumSpeed, systemImage: "arrow.up.right")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            Text("RIDE STATS")
                .font(.caption.weight(.bold))
                .tracking(Constants.titleTracking)
                .foregroundStyle(DesignColor.informational)
            Text(state.statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityValue("\(state.totalDistance.valueText) \(state.totalDistance.unit)")
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
        static let titleTracking: CGFloat = 1.1
        static let heroFontSize: CGFloat = 34
    }
}
