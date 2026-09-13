import DesignSystem
import SwiftUI

struct WatchRideDashboardContent: View {
    let state: WatchDashboardViewState

    var body: some View {
        WatchDashboardContentLayout { batteryRingDiameter in
            VStack(spacing: DesignSpace.extraExtraSmall) {
                WatchBatteryRing(
                    percentage: state.batteryPercent, tint: WatchBatteryStyle.tint(for: state.batteryEmphasis)
                )
                    .frame(width: batteryRingDiameter, height: batteryRingDiameter)
                HStack(spacing: DesignSpace.extraSmall) {
                    WatchDashboardMetric(
                        title: state.showsMap ? .watchCompanionMap : .watchCompanionState, value: state.map
                    )
                    Divider()
                        .padding(.top, DesignSpace.extraSmall)
                    WatchDashboardMetric(title: .watchCompanionTraction, value: state.traction)
                }
                WatchCompanionStatus(state: state)
            }
        }
    }
}
