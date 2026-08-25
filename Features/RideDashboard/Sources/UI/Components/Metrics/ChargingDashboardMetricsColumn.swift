import DesignSystem
import SwiftUI

struct ChargingDashboardMetricsColumn: View {
    let viewState: ChargingDashboardViewState
    let compact: Bool

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)
            VStack(alignment: .leading, spacing: .zero) {
                metric(title: "MAX POWER", metric: viewState.maximumPower)
                separator
                metric(title: "CURRENT", metric: viewState.reportedCurrent)
                separator
                metric(title: "BATTERY TEMP", metric: viewState.batteryTemperature)
            }
            Spacer(minLength: .zero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    private var separator: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(height: Constants.separatorHeight)
            .padding(.vertical, compact ? DesignSpace.small : DesignSpace.medium)
    }

    private func metric(
        title: String,
        metric: DashboardMetricViewData
    ) -> some View {
        DashboardMetricPanel(
            title: title,
            metric: metric,
            tint: DesignColor.primaryText,
            alignment: .leading
        )
    }

    private enum Constants {
        static let separatorHeight: CGFloat = 1
    }
}
