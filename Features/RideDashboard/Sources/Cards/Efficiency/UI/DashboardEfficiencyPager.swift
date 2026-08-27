import SwiftUI

struct DashboardEfficiencyPager: View {
    @Binding var selection: EfficiencyDashboardPage
    let state: DashboardEfficiencyViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardHorizontalCardPager(
            pages: EfficiencyDashboardPage.allCases,
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
