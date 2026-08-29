import SwiftUI

struct DashboardRightStatusColumn: View {
    let gear: DashboardGearViewData
    let powerMode: DashboardPowerModeViewData
    let showsPowerMode: Bool

    var body: some View {
        VStack(spacing: Constants.spacing) {
            if showsPowerMode {
                DashboardPowerModeSummary(state: powerMode, layout: .sidebar)
                    .transition(.opacity)
            }

            DashboardGearPanel(state: gear)
        }
        .padding(.horizontal, Constants.horizontalPadding)
    }

    private enum Constants {
        static let spacing: CGFloat = 10
        static let horizontalPadding: CGFloat = 6
    }
}
