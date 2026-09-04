import DesignSystem
import SwiftUI

struct RideNavigationMetricsRow: View {
    let state: RideNavigationViewState

    var body: some View {
        HStack(alignment: .center, spacing: DesignSpace.small) {
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
            RideNavigationMetric(
                value: state.batteryText,
                unit: "",
                label: .rideNavigationMetricBike
            )
            if let progressText = state.gpxProgressText {
                RideNavigationMetric(
                    value: progressText,
                    unit: "",
                    label: .rideNavigationMetricGpxProgress
                )
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}
