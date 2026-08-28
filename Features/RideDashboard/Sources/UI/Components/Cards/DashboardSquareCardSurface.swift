import DesignSystem
import SwiftUI

struct DashboardSquareCardSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width - DashboardCardSurfaceStyle.horizontalInset * 2
            let availableHeight = proxy.size.height
                - DashboardCardSurfaceStyle.topInset
                - DashboardCardSurfaceStyle.bottomInset
            let baseSide = max(.zero, min(availableWidth, availableHeight))
            let side = max(
                .zero,
                min(
                    availableWidth,
                    baseSide * DashboardSquareCardSurfaceConstants.expansionFactor,
                    DashboardSquareCardSurfaceConstants.maximumSide
                )
            )
            let verticalCenter = DashboardCardSurfaceStyle.topInset + availableHeight / 2

            content
                .padding(DashboardSquareCardSurfaceConstants.contentPadding)
                .frame(width: side, height: side)
                .background(cardShape.fill(DesignColor.groupedSurface))
                .overlay(
                    cardShape.stroke(
                        DesignColor.border,
                        lineWidth: DashboardCardSurfaceStyle.borderWidth
                    )
                )
                .position(
                    x: proxy.size.width / 2,
                    y: verticalCenter
                )
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DashboardCardSurfaceStyle.cornerRadius,
            style: .continuous
        )
    }

}

private enum DashboardSquareCardSurfaceConstants {
    static let contentPadding: CGFloat = 14
    static let expansionFactor: CGFloat = 1.08 * 1.045
    static let maximumSide: CGFloat = 360 * 1.045
}
