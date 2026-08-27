import SwiftUI

struct DashboardRangePager: View {
    @Binding var selection: RangeDashboardPage
    let state: DashboardRangeViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardHorizontalCardPager(
            pages: RangeDashboardPage.allCases,
            selection: $selection,
            reduceMotion: reduceMotion,
            accessibilityLabel: "Range pages",
            accessibilityValue: \.accessibilityLabel
        ) { page in
            switch page {
            case .range:
                DashboardRangeLiveCard(state: state)
            case .battery:
                DashboardBatteryTripCard(state: state)
            }
        }
    }
}
