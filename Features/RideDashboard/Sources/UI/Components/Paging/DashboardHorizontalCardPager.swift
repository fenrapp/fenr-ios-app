import DesignSystem
import SwiftUI

struct DashboardHorizontalCardPager<Page: Hashable, Content: View>: View {
    let pages: [Page]
    @Binding var selection: Page
    let reduceMotion: Bool
    let accessibilityLabel: String
    let accessibilityValue: (Page) -> String
    let onInteractionChanged: (Bool) -> Void
    let indicatorVerticalOffset: CGFloat
    private let content: (Page) -> Content

    init(
        pages: [Page],
        selection: Binding<Page>,
        reduceMotion: Bool,
        accessibilityLabel: String,
        accessibilityValue: @escaping (Page) -> String,
        onInteractionChanged: @escaping (Bool) -> Void = { _ in },
        indicatorVerticalOffset: CGFloat = .zero,
        @ViewBuilder content: @escaping (Page) -> Content
    ) {
        self.pages = pages
        _selection = selection
        self.reduceMotion = reduceMotion
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.onInteractionChanged = onInteractionChanged
        self.indicatorVerticalOffset = indicatorVerticalOffset
        self.content = content
    }

    var body: some View {
        DashboardPager(
            pages: pages,
            selection: $selection,
            axis: .horizontal,
            reduceMotion: reduceMotion,
            accessibilityLabel: accessibilityLabel,
            accessibilityValue: accessibilityValue,
            onInteractionChanged: onInteractionChanged,
            content: content
        )
        .overlay(alignment: .bottom) {
            DashboardPageIndicator(
                pages: pages,
                selection: selection,
                axis: .horizontal,
                activeColor: DesignColor.informational
            )
            .padding(.bottom, DashboardHorizontalCardPagerConstants.indicatorBottomPadding)
            .offset(y: indicatorVerticalOffset)
        }
    }
}

private enum DashboardHorizontalCardPagerConstants {
    static let indicatorBottomPadding: CGFloat = 10
}
