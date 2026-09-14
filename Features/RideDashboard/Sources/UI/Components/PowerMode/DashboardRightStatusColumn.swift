import SwiftUI

struct DashboardRightStatusColumn: View {
    let gear: DashboardGearViewData
    let powerMode: DashboardPowerModeViewData
    let showsPowerMode: Bool

    var body: some View {
        VStack(spacing: DashboardSideStatusLayoutMetrics.spacing) {
            DashboardGearPanel(state: gear)

            if showsPowerMode {
                DashboardPowerModeSummary(state: powerMode, layout: .sidebar)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        width: DashboardSideStatusLayoutMetrics.primaryStatusWidth,
                        height: DashboardSideStatusLayoutMetrics.secondaryStatusHeight
                    )
                    .transition(.opacity)
            }
        }
        .frame(
            height: showsPowerMode ? DashboardSideStatusLayoutMetrics.columnHeight : nil,
            alignment: .top
        )
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private enum Constants {
        static let horizontalPadding: CGFloat = 6
    }
}
