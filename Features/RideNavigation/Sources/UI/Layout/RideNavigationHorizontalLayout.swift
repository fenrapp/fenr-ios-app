import SwiftUI

struct RideNavigationHorizontalLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(
            width: sizes.map(\.width).reduce(0, +) + totalSpacing(for: sizes.count),
            height: sizes.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var nextX = bounds.minX
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            subview.place(
                at: CGPoint(x: nextX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            nextX += size.width + spacing
        }
    }

    private func totalSpacing(for count: Int) -> CGFloat {
        CGFloat(max(0, count - 1)) * spacing
    }
}
