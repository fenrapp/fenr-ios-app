import SwiftUI

struct DashboardSystemHealthPager: View {
    let pages: [SystemHealthDashboardPage]
    @Binding var selection: SystemHealthDashboardPage
    let state: DashboardSystemHealthViewData
    let reduceMotion: Bool

    var body: some View {
        DashboardHorizontalCardPager(
            pages: pages,
            selection: $selection,
            reduceMotion: reduceMotion,
            accessibilityLabel: "System health pages",
            accessibilityValue: \.accessibilityLabel,
            indicatorVerticalOffset: Constants.indicatorVerticalOffset
        ) { page in
            switch page {
            case .health: DashboardSystemHealthCard(state: state)
            case .cells: DashboardSystemHealthCellsCard(state: state)
            case .thermal: DashboardSystemHealthThermalCard(state: state)
            }
        }
    }

    private enum Constants {
        static let indicatorVerticalOffset: CGFloat = 10
    }
}
