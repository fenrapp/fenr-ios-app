import SwiftUI

struct DashboardPager<Page: Hashable, Content: View>: View {
    let pages: [Page]
    @Binding var selection: Page
    let axis: Axis
    let reduceMotion: Bool
    let accessibilityLabel: String
    let accessibilityValue: (Page) -> String
    let onInteractionChanged: (Bool) -> Void
    private let content: (Page) -> Content

    @GestureState private var dragTranslation: CGFloat = .zero
    @State private var lockedGestureAxis: Axis?

    init(
        pages: [Page],
        selection: Binding<Page>,
        axis: Axis,
        reduceMotion: Bool,
        accessibilityLabel: String,
        accessibilityValue: @escaping (Page) -> String,
        onInteractionChanged: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder content: @escaping (Page) -> Content
    ) {
        self.pages = pages
        _selection = selection
        self.axis = axis
        self.reduceMotion = reduceMotion
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.onInteractionChanged = onInteractionChanged
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                pageLayout {
                    ForEach(pages, id: \.self) { page in
                        content(page)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .offset(stackOffset(containerSize: proxy.size))
                .animation(pageAnimation, value: selection)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(pagingGesture(containerSize: proxy.size))
        }
        .clipped()
        .onAppear(perform: normalizeSelection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue(selection))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selectRelativePage(offset: 1)
            case .decrement: selectRelativePage(offset: -1)
            @unknown default: break
            }
        }
    }

    private var selectedIndex: Int {
        pages.firstIndex(of: selection) ?? .zero
    }

    private var pageAnimation: Animation? {
        reduceMotion ? nil : .interactiveSpring(
            response: DashboardPagerConstants.springResponse,
            dampingFraction: DashboardPagerConstants.springDampingFraction
        )
    }

    private func pageLayout<LayoutContent: View>(
        @ViewBuilder content: () -> LayoutContent
    ) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: .zero))
            : AnyLayout(VStackLayout(spacing: .zero))
        return layout(content)
    }

    private func stackOffset(containerSize: CGSize) -> CGSize {
        let pageLength = primaryLength(containerSize)
        let centeringCompensation = CGFloat(max(pages.count - 1, .zero)) * pageLength / 2
        let offset = centeringCompensation
            - CGFloat(selectedIndex) * pageLength
            + resistedDragTranslation
        return axis == .horizontal
            ? CGSize(width: offset, height: .zero)
            : CGSize(width: .zero, height: offset)
    }

    private var resistedDragTranslation: CGFloat {
        guard !pages.isEmpty else { return .zero }
        let isPastFirst = selectedIndex == pages.startIndex && dragTranslation > .zero
        let isPastLast = selectedIndex == pages.index(before: pages.endIndex)
            && dragTranslation < .zero
        return isPastFirst || isPastLast
            ? dragTranslation * DashboardPagerConstants.edgeResistance
            : dragTranslation
    }

    private func pagingGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: DashboardPagerConstants.minimumDragDistance)
            .updating($dragTranslation) { value, state, _ in
                guard lockedGestureAxis == axis else { return }
                state = primaryTranslation(value.translation)
            }
            .onChanged { value in
                guard lockedGestureAxis == nil else { return }
                let gestureAxis = dominantAxis(value.translation)
                lockedGestureAxis = gestureAxis
                guard gestureAxis == axis else { return }
                onInteractionChanged(true)
            }
            .onEnded { value in
                let gestureAxis = lockedGestureAxis ?? dominantAxis(value.translation)
                lockedGestureAxis = nil
                guard gestureAxis == axis else { return }
                updateSelection(
                    projectedTranslation: primaryTranslation(value.predictedEndTranslation),
                    pageLength: primaryLength(containerSize)
                )
                onInteractionChanged(false)
            }
    }

    private func updateSelection(projectedTranslation: CGFloat, pageLength: CGFloat) {
        let threshold = pageLength * DashboardPagerConstants.pageChangeThresholdRatio
        if projectedTranslation <= -threshold {
            selectRelativePage(offset: 1)
        } else if projectedTranslation >= threshold {
            selectRelativePage(offset: -1)
        }
    }

    private func selectRelativePage(offset: Int) {
        guard !pages.isEmpty else { return }
        let index = min(
            max(selectedIndex + offset, pages.startIndex),
            pages.index(before: pages.endIndex)
        )
        guard index != selectedIndex else { return }
        selection = pages[index]
    }

    private func normalizeSelection() {
        guard let firstPage = pages.first, !pages.contains(selection) else { return }
        selection = firstPage
    }

    private func primaryLength(_ size: CGSize) -> CGFloat {
        axis == .horizontal ? size.width : size.height
    }

    private func primaryTranslation(_ translation: CGSize) -> CGFloat {
        axis == .horizontal ? translation.width : translation.height
    }

    private func dominantAxis(_ translation: CGSize) -> Axis {
        abs(translation.width) > abs(translation.height) ? .horizontal : .vertical
    }
}

enum DashboardPagerConstants {
    static let minimumDragDistance: CGFloat = 12
    static let pageChangeThresholdRatio: CGFloat = 0.16
    static let edgeResistance: CGFloat = 0.2
    static let springResponse = 0.32
    static let springDampingFraction = 0.86
}
