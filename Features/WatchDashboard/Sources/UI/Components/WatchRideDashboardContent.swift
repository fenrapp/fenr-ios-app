import DesignSystem
import SwiftUI

struct WatchRideDashboardContent: View {
    let state: WatchDashboardViewState
    let onChangeBike: () -> Void

    var body: some View {
        WatchDashboardContentLayout { batteryRingDiameter in
            VStack(spacing: DesignSpace.small) {
                WatchBatteryRing(percentage: state.batteryPercent, tint: .green)
                    .frame(width: batteryRingDiameter, height: batteryRingDiameter)
                VStack(spacing: DesignSpace.extraExtraSmall) {
                    Text("GEAR")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(state.gear)
                        .font(.system(size: Constants.gearFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                WatchDashboardMetric(title: "ODOMETER", value: state.odometer ?? "--")
                WatchChangeBikeButton(action: onChangeBike)
            }
        }
    }

    private enum Constants {
        static let gearFontSize: CGFloat = 42
    }
}

#if DEBUG
#Preview {
    WatchRideDashboardContent(
        state: .init(mode: .ride, batteryPercent: 72, gear: "3", odometer: "180.0 km"),
        onChangeBike: {}
    )
}
#endif
