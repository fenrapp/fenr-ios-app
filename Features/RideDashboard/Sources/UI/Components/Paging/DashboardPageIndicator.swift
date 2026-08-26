import DesignSystem
import SwiftUI

struct DashboardPageIndicator<Page: Hashable>: View {
    let pages: [Page]
    let selection: Page
    let axis: Axis
    let activeColor: Color

    var body: some View {
        indicatorLayout {
            ForEach(pages, id: \.self) { page in
                Capsule()
                    .fill(page == selection ? activeColor : DesignColor.inactive)
                    .frame(
                        width: indicatorWidth(isSelected: page == selection),
                        height: indicatorHeight(isSelected: page == selection)
                    )
            }
        }
        .padding(primaryEdges, DashboardPageIndicatorConstants.primaryPadding)
        .padding(crossEdges, DashboardPageIndicatorConstants.crossPadding)
        .background(Capsule().fill(DesignColor.groupedSurface))
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func indicatorLayout<LayoutContent: View>(
        @ViewBuilder content: () -> LayoutContent
    ) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: DashboardPageIndicatorConstants.spacing))
            : AnyLayout(VStackLayout(spacing: DashboardPageIndicatorConstants.spacing))
        return layout(content)
    }

    private func indicatorWidth(isSelected: Bool) -> CGFloat {
        axis == .horizontal
            ? indicatorLength(isSelected: isSelected)
            : DashboardPageIndicatorConstants.thickness
    }

    private func indicatorHeight(isSelected: Bool) -> CGFloat {
        axis == .vertical
            ? indicatorLength(isSelected: isSelected)
            : DashboardPageIndicatorConstants.thickness
    }

    private func indicatorLength(isSelected: Bool) -> CGFloat {
        isSelected
            ? DashboardPageIndicatorConstants.activeLength
            : DashboardPageIndicatorConstants.inactiveLength
    }

    private var primaryEdges: Edge.Set {
        axis == .horizontal ? .horizontal : .vertical
    }

    private var crossEdges: Edge.Set {
        axis == .horizontal ? .vertical : .horizontal
    }
}

private enum DashboardPageIndicatorConstants {
    static let spacing: CGFloat = 6
    static let activeLength: CGFloat = 15
    static let inactiveLength: CGFloat = 5
    static let thickness: CGFloat = 5
    static let primaryPadding: CGFloat = 8
    static let crossPadding: CGFloat = 7
}
