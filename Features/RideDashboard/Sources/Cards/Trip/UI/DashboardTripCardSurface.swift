import DesignSystem
import SwiftUI

struct DashboardTripCardSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DashboardTripCardSurfaceConstants.contentPadding)
            .background(cardShape.fill(DesignColor.groupedSurface))
            .overlay(
                cardShape.stroke(
                    DesignColor.border,
                    lineWidth: DashboardTripCardSurfaceConstants.borderWidth
                )
            )
            .padding(.horizontal, DashboardTripCardSurfaceConstants.horizontalInset)
            .padding(.top, DashboardTripCardSurfaceConstants.topInset)
            .padding(.bottom, DashboardTripCardSurfaceConstants.bottomInset)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: DashboardTripCardSurfaceConstants.cornerRadius,
            style: .continuous
        )
    }
}

private enum DashboardTripCardSurfaceConstants {
    static let contentPadding: CGFloat = 18
    static let horizontalInset: CGFloat = 22
    static let topInset: CGFloat = 86
    static let bottomInset: CGFloat = 50
    static let cornerRadius: CGFloat = 24
    static let borderWidth: CGFloat = 1
}
