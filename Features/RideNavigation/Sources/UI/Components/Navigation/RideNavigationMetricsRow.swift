import DesignSystem
import SwiftUI

struct RideNavigationMetricsRow: View {
    @ScaledMetric(relativeTo: .title3) private var minimumMetricWidth = Constants.minimumMetricWidth
    let state: RideNavigationViewState

    var rangeState = RideNavigationRangeState()
    var showsEstimatedRange = false
    var onToggleBatteryDisplay: () -> Void = {}

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: DesignSpace.small) { metrics }
                .fixedSize(horizontal: true, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumMetricWidth), alignment: .leading)],
                      alignment: .leading, spacing: DesignSpace.small) { metrics }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rideNavigation.metrics")
    }

    @ViewBuilder
    private var metrics: some View {
        if let connectionNoticeText = state.connectionNoticeText {
            ViewThatFits(in: .horizontal) {
                Label {
                    Text(verbatim: connectionNoticeText)
                } icon: {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                }
                .lineLimit(1)
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .accessibilityLabel(Text(verbatim: connectionNoticeText))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }

        RideNavigationMetric(
            value: state.speedText,
            unit: state.speedUnit,
            label: .rideNavigationMetricSpeed
        )
        RideNavigationMetric(
            value: state.modeText,
            unit: "",
            label: .rideNavigationMetricPower
        )
        Button(action: onToggleBatteryDisplay) {
            RideNavigationMetric(
                value: showsEstimatedRange ? rangeState.value : state.batteryText,
                unit: showsEstimatedRange ? rangeState.unit : "",
                label: showsEstimatedRange ? .rideNavigationEstimatedRange : .rideNavigationMetricBike
            )
            .frame(minHeight: Constants.minimumTapHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(showsEstimatedRange
            ? Text(.rideNavigationShowBatteryPercentage) : Text(.rideNavigationShowEstimatedRange))
        .accessibilityIdentifier("rideNavigation.batteryDisplay")
        if let progressText = state.gpxProgressText {
            RideNavigationMetric(
                value: progressText,
                unit: "",
                label: .rideNavigationMetricGpxProgress
            )
        }
    }

    private enum Constants {
        static let minimumMetricWidth: CGFloat = 100
        static let minimumTapHeight: CGFloat = 44
    }
}
