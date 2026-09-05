import SwiftUI

struct DashboardSettingsCard: View {
    let openSettings: () -> Void

    var body: some View {
        DashboardDestinationCard(
            symbolName: "gearshape.circle.fill",
            eyebrow: .rideDashboardHeaderSettings,
            title: .rideDashboardSettingsTagline,
            detail: .rideDashboardSettingsDetail,
            buttonTitle: .rideDashboardSettingsOpen,
            buttonSymbolName: "gearshape.fill",
            accessibilityIdentifier: "dashboard.settings",
            open: openSettings
        )
    }
}
