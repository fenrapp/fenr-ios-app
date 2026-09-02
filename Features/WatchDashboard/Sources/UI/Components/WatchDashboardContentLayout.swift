import DesignSystem
import SwiftUI

struct WatchDashboardContentLayout<Content: View>: View {
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content(batteryRingDiameter(in: geometry.size))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DesignSpace.extraSmall)
                    .frame(minHeight: geometry.size.height)
            }
        }
    }

    private func batteryRingDiameter(in size: CGSize) -> CGFloat {
        min(
            size.width * WatchDashboardContentLayoutConstants.batteryRingWidthMultiplier,
            size.height * WatchDashboardContentLayoutConstants.batteryRingHeightMultiplier
        )
    }
}

private enum WatchDashboardContentLayoutConstants {
    static let batteryRingWidthMultiplier = 0.78
    static let batteryRingHeightMultiplier = 0.6
}

struct WatchChangeBikeButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(.watchDashboardChangeBike)
        }
            .font(.caption)
    }
}
