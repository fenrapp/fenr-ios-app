import DesignSystem
import SwiftUI

struct DashboardAdaptiveCardSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(
                .zero,
                proxy.size.width - DashboardAdaptiveCardSurfaceConstants.horizontalInset * 2
            )
            let availableHeight = max(
                .zero,
                proxy.size.height
                    - DashboardAdaptiveCardSurfaceConstants.topInset
                    - DashboardAdaptiveCardSurfaceConstants.bottomInset
            )
            let cardWidth = min(
                availableWidth,
                DashboardAdaptiveCardSurfaceConstants.maximumWidth
            ) * DashboardAdaptiveCardSurfaceConstants.scale
            let cardHeight = min(
                availableHeight,
                DashboardAdaptiveCardSurfaceConstants.maximumHeight
            ) * DashboardAdaptiveCardSurfaceConstants.scale
            let verticalCenter = DashboardAdaptiveCardSurfaceConstants.topInset
                + availableHeight / 2

            content
                .padding(DashboardAdaptiveCardSurfaceConstants.contentPadding)
                .frame(width: cardWidth, height: cardHeight)
                .background(cardShape.fill(DesignColor.groupedSurface))
                .overlay(
                    cardShape.stroke(
                        DesignColor.border,
                        lineWidth: DashboardCardSurfaceStyle.borderWidth
                    )
                )
                .position(x: proxy.size.width / 2, y: verticalCenter)
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DashboardCardSurfaceStyle.cornerRadius,
            style: .continuous
        )
    }
}

private enum DashboardAdaptiveCardSurfaceConstants {
    static let contentPadding: CGFloat = 18
    static let horizontalInset: CGFloat = 8
    static let topInset: CGFloat = 32
    static let bottomInset: CGFloat = 40
    static let maximumWidth: CGFloat = 480
    static let maximumHeight: CGFloat = 380
    static let scale: CGFloat = 0.9 * 1.05
}
