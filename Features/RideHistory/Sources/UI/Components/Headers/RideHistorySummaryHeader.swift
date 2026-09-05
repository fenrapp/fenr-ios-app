import DesignSystem
import SwiftUI

struct RideHistorySummaryHeader: View {
    let summary: RideHistoryViewState.Summary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.large) {
            distanceSummary
            Divider().overlay(DesignColor.border)
            metrics
        }
        .padding(.vertical, DesignSpace.extraSmall)
        .accessibilityElement(children: .contain)
    }

    private var distanceSummary: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignSpace.small))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignSpace.small))
            layout {
                Text(verbatim: summary.distanceText)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DesignColor.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                rideCount
            }
            Text(.rideHistorySummaryTotalDistance)
                .font(.caption)
                .foregroundStyle(DesignColor.secondaryText)
        }
    }

    private var rideCount: some View {
        Text(verbatim: summary.rideCountText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignColor.primaryText)
            .padding(.horizontal, DesignSpace.small)
            .padding(.vertical, DesignSpace.extraSmall)
            .background(DesignColor.elevatedSurface, in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    private var metrics: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignSpace.medium))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignSpace.small))
        return layout {
            RideHistorySummaryMetric(
                label: .rideHistoryMetricRideTime, symbolName: "clock", value: summary.durationText
            )
            RideHistorySummaryMetric(
                label: .rideHistoryMetricAverageSpeed, symbolName: "gauge.with.dots.needle.33percent",
                value: summary.averageSpeedText
            )
            RideHistorySummaryMetric(
                label: .rideHistoryMetricMaximumSpeed, symbolName: "gauge.with.dots.needle.67percent",
                value: summary.maximumSpeedText
            )
        }
    }
}
