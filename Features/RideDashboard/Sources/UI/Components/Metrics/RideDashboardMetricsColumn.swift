import DesignSystem
import SwiftUI

struct RideDashboardMetricsColumn: View {
    let battery: RideDashboardViewState.Battery
    let odometer: DashboardMetricViewData
    let compact: Bool

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)
            VStack(alignment: .leading, spacing: .zero) {
                DashboardBatteryPanel(state: battery)
                separator
                DashboardMetricPanel(
                    title: "ODOMETER",
                    metric: odometer,
                    tint: DesignColor.primaryText,
                    alignment: .leading
                )
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

    private enum Constants {
        static let separatorHeight: CGFloat = 1
    }
}
