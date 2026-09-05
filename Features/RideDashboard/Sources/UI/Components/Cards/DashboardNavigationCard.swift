import SwiftUI

struct DashboardNavigationCard: View {
    let isNavigationActive: Bool
    let openNavigation: () -> Void

    var body: some View {
        DashboardDestinationCard(
            symbolName: "map.circle.fill",
            eyebrow: .rideDashboardNavigationTitle,
            title: isNavigationActive ? .rideDashboardNavigationRunning : .rideDashboardNavigationTagline,
            detail: isNavigationActive ? .rideDashboardNavigationRunningDetail : .rideDashboardNavigationInactiveDetail,
            buttonTitle: isNavigationActive ? .rideDashboardNavigationReturn : .rideDashboardNavigationOpen,
            buttonSymbolName: isNavigationActive ? "arrow.up.left.and.arrow.down.right" : "location.north.fill",
            accessibilityIdentifier: "dashboard.navigation.open",
            open: openNavigation
        )
    }
}
