import DesignSystem
import SwiftUI

struct WatchChargingDashboardContent: View {
    let state: WatchDashboardViewState
    let onChangeBike: () -> Void

    var body: some View {
        WatchDashboardContentLayout { batteryRingDiameter in
            VStack(spacing: DesignSpace.small) {
                Text(
                    state.chargeETA.map {
                        .watchDashboardChargingETA(eta: $0)
                    } ?? .watchDashboardCharging
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                WatchBatteryRing(percentage: state.batteryPercent, tint: .cyan)
                    .frame(width: batteryRingDiameter, height: batteryRingDiameter)
                HStack(spacing: DesignSpace.extraSmall) {
                    WatchDashboardMetric(
                        title: .watchDashboardPower,
                        value: state.chargingPower ?? "--"
                    )
                    Divider()
                    WatchDashboardMetric(
                        title: .watchDashboardCurrent,
                        value: state.chargingCurrent ?? "--"
                    )
                }
                WatchDashboardMetric(
                    title: .watchDashboardPackTemperature,
                    value: state.batteryTemperature ?? "--"
                )
                WatchChangeBikeButton(action: onChangeBike)
            }
        }
    }
}

#if DEBUG
#Preview {
    WatchChargingDashboardContent(
        state: .init(
            mode: .charging,
            batteryPercent: 82,
            chargingPower: "1.8 kW",
            chargingCurrent: "4.3 A",
            batteryTemperature: "31.2°C",
            chargeETA: "38 min"
        ),
        onChangeBike: {}
    )
}
#endif
