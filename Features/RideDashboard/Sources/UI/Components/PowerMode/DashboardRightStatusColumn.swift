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
                    .frame(height: DashboardSideStatusLayoutMetrics.secondaryStatusHeight)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private enum Constants {
        static let horizontalPadding: CGFloat = 6
    }
}
