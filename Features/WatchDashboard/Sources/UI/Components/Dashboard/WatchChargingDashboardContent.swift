import DesignSystem
import SwiftUI

struct WatchChargingDashboardContent: View {
    let state: WatchDashboardViewState

    var body: some View {
        WatchDashboardContentLayout(hasHeading: true) { batteryRingDiameter in
            VStack(spacing: DesignSpace.extraExtraSmall) {
                Text(state.chargeETA.map { .watchDashboardChargingETA(eta: $0) } ?? .watchDashboardCharging)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                WatchBatteryRing(
                    percentage: state.batteryPercent, tint: WatchBatteryStyle.tint(for: state.batteryEmphasis)
                )
                    .frame(width: batteryRingDiameter, height: batteryRingDiameter)
                HStack(spacing: DesignSpace.extraSmall) {
                    WatchDashboardMetric(title: .watchCompanionMaximumPower, value: state.chargingPower)
                    Divider()
                        .padding(.top, DesignSpace.extraSmall)
                    WatchDashboardMetric(title: .watchDashboardCurrent, value: state.chargingCurrent)
                }
                WatchCompanionStatus(state: state)
            }
        }
    }
}
