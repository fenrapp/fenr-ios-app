import SwiftUI

struct DashboardRideDynamicsPager: View {
    let pages: [RideDynamicsDashboardPage]
    @Binding var selection: RideDynamicsDashboardPage
    let state: DashboardRideDynamicsViewData
    let reduceMotion: Bool
    let calibrate: () -> Void

    var body: some View {
        GeometryReader { proxy in
            DashboardHorizontalCardPager(
                pages: pages,
                selection: $selection,
                reduceMotion: reduceMotion,
                accessibilityLabel: rideDashboardLocalized(.rideDashboardDynamicsPagesAccessibility),
                accessibilityValue: \.accessibilityLabel,
                indicatorVerticalOffset: indicatorVerticalOffset(for: proxy.size.height)
            ) { page in
                switch page {
                case .lean: DashboardLeanCard(state: state, reduceMotion: reduceMotion, calibrate: calibrate)
                case .pitch: DashboardPitchCard(state: state, reduceMotion: reduceMotion, calibrate: calibrate)
                case .course: DashboardCourseCard(state: state, reduceMotion: reduceMotion)
                }
            }
        }
    }

    private func indicatorVerticalOffset(for availableHeight: CGFloat) -> CGFloat {
        availableHeight <= Constants.compactHeightThreshold
            ? Constants.compactIndicatorVerticalOffset
            : Constants.indicatorVerticalOffset
    }

    private enum Constants {
        static let indicatorVerticalOffset: CGFloat = 10
        static let compactIndicatorVerticalOffset: CGFloat = 14
        static let compactHeightThreshold: CGFloat = 380
    }
}
