import DesignSystem
import SwiftUI

struct WatchDashboardContentLayout<Content: View>: View {
    var hasHeading = false
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            content(batteryRingDiameter(in: geometry.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DesignSpace.extraExtraSmall)
        }
    }

    private func batteryRingDiameter(in size: CGSize) -> CGFloat {
        let headingHeight = hasHeading ? WatchDashboardLayoutConstants.headingHeight : 0
        let reservedHeight = WatchDashboardLayoutConstants.metricsAndStatusHeight + headingHeight
        let width = size.width * WatchDashboardLayoutConstants.widthFraction
        return max(WatchDashboardLayoutConstants.minimumDiameter, min(width, size.height - reservedHeight))
    }
}

private enum WatchDashboardLayoutConstants {
    static let metricsAndStatusHeight: CGFloat = 78
    static let headingHeight: CGFloat = 22
    static let minimumDiameter: CGFloat = 44
    static let widthFraction = 0.7
}
