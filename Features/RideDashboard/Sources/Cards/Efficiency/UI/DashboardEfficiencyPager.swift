import SwiftUI

struct DashboardEfficiencyPager: View {
    let pages: [EfficiencyDashboardPage]
    @Binding var selection: EfficiencyDashboardPage
    let state: DashboardEfficiencyViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardHorizontalCardPager(
            pages: pages,
            selection: $selection,
            reduceMotion: reduceMotion,
            accessibilityLabel: "Efficiency pages",
            accessibilityValue: \.accessibilityLabel
        ) { page in
            switch page {
            case .live:
                DashboardEfficiencyLiveCard(state: state)
            case .trend:
                DashboardEfficiencyTrendCard(state: state)
            }
        }
    }
}
