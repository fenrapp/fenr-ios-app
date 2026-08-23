import DesignSystem
import SwiftUI

struct ChargingDashboardMetricsColumn: View {
    let viewState: ChargingDashboardViewState
    let compact: Bool

    var body: some View {
        VStack(spacing: .zero) {
            Spacer(minLength: .zero)
            VStack(alignment: .leading, spacing: .zero) {
                metric(title: "MAX POWER", measurement: viewState.maximumPower, fractionDigits: 1)
                separator
                metric(title: "CURRENT", measurement: viewState.reportedCurrent, fractionDigits: 1)
                separator
                metric(title: "BATTERY TEMP", measurement: viewState.batteryTemperature, fractionDigits: 0)
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
        measurement: RideDashboardMeasurement?,
        fractionDigits: Int
    ) -> some View {
        DashboardMetricPanel(
            title: title,
            measurement: measurement,
            fractionDigits: fractionDigits,
            tint: DesignColor.primaryText,
            alignment: .leading
        )
    }

    private enum Constants {
        static let separatorHeight: CGFloat = 1
    }
}
