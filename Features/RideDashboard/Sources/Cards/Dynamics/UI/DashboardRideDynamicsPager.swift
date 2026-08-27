import SwiftUI

struct DashboardRideDynamicsPager: View {
    @Binding var selection: RideDynamicsDashboardPage
    let state: DashboardRideDynamicsViewData
    let reduceMotion: Bool
    let calibrate: () -> Void

    var body: some View {
        DashboardHorizontalCardPager(
            pages: RideDynamicsDashboardPage.allCases,
            selection: $selection,
            reduceMotion: reduceMotion,
            accessibilityLabel: "Ride dynamics pages",
            accessibilityValue: \.accessibilityLabel,
            indicatorVerticalOffset: Constants.indicatorVerticalOffset
        ) { page in
            switch page {
            case .lean: DashboardLeanCard(state: state, calibrate: calibrate)
            case .pitch: DashboardPitchCard(state: state, calibrate: calibrate)
            case .course: DashboardCourseCard(state: state, reduceMotion: reduceMotion)
            }
        }
    }

    private enum Constants {
        static let indicatorVerticalOffset: CGFloat = 10
    }
}
