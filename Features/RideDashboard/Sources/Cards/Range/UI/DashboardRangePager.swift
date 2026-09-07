import SwiftUI

struct DashboardRangePager: View {
    let pages: [RangeDashboardPage]
    @Binding var selection: RangeDashboardPage
    let state: DashboardRangeViewData
    let reduceMotion: Bool
    let retryHistory: () -> Void

    var body: some View {
        DashboardHorizontalCardPager(
            pages: pages,
            selection: $selection,
            reduceMotion: reduceMotion,
            accessibilityLabel: rideDashboardLocalized(.rideDashboardRangePagesAccessibility),
            accessibilityValue: \.accessibilityLabel
        ) { page in
            switch page {
            case .range:
                DashboardRangeLiveCard(state: state, retryHistory: retryHistory)
            case .battery:
                DashboardBatteryTripCard(state: state)
            }
        }
    }
}
