import DesignSystem
import SwiftUI

struct DashboardTripCardSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DashboardCardSurfaceStyle.contentPadding)
            .background(cardShape.fill(DesignColor.groupedSurface))
            .overlay(
                cardShape.stroke(
                    DesignColor.border,
                    lineWidth: DashboardCardSurfaceStyle.borderWidth
                )
            )
            .padding(.horizontal, DashboardCardSurfaceStyle.horizontalInset)
            .padding(.top, DashboardCardSurfaceStyle.topInset)
            .padding(.bottom, DashboardCardSurfaceStyle.bottomInset)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DashboardCardSurfaceStyle.cornerRadius,
            style: .continuous
        )
    }
}
