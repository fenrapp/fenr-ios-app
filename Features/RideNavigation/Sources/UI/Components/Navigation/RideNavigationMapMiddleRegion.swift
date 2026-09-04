import DesignSystem
import SwiftUI

struct RideNavigationMapMiddleRegion<Content: View>: View {
    let hasContent: Bool
    let showsScrollIndicators: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if hasContent {
            ZStack(alignment: .top) {
                ViewThatFits(in: .vertical) {
                    content()
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.vertical) {
                        content()
                    }
                    .scrollIndicators(showsScrollIndicators ? .visible : .hidden)
                    .frame(maxHeight: RideNavigationMapMiddleRegionConstants.maximumScrollHeight)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            Spacer(minLength: DesignSpace.medium)
                .allowsHitTesting(false)
        }
    }

}

private enum RideNavigationMapMiddleRegionConstants {
    static let maximumScrollHeight: CGFloat = 144
}
