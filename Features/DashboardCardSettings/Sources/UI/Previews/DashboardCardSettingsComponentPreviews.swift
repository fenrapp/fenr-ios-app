import SwiftUI

#Preview("Visibility rows · Regular") {
    NavigationStack {
        DashboardCardSettingsRowsPreview()
            .navigationTitle("Dashboard Cards")
    }
}

#Preview("Visibility rows · Accessibility XXXL") {
    NavigationStack {
        DashboardCardSettingsRowsPreview()
            .navigationTitle("Dashboard Cards")
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

private struct DashboardCardSettingsRowsPreview: View {
    @State private var isEnabledCardVisible = true
    @State private var isProtectedCardVisible = true

    var body: some View {
        List {
            DashboardCardVisibilityRow(
                title: "Long-range efficiency and battery health overview",
                isEnabled: true,
                disabledHint: nil,
                isVisible: $isEnabledCardVisible
            ) {
                DashboardCardRowLabel(
                    title: "Long-range efficiency and battery health overview",
                    detail: "Shows a deliberately long description for adaptive row layout verification.",
                    thumbnail: .init(style: .chart, systemImage: "leaf.fill", accent: .positive)
                )
            }

            DashboardCardVisibilityRow(
                title: "Protected Bike Lock controls",
                isEnabled: false,
                disabledHint: "Bike Lock must remain visible while unlock protection is configured",
                isVisible: $isProtectedCardVisible
            ) {
                DashboardCardRowLabel(
                    title: "Protected Bike Lock controls",
                    detail: "Required while unlock protection remains configured for this motorcycle.",
                    thumbnail: .init(style: .lock, systemImage: "lock.fill", accent: .accent)
                )
            }
        }
    }
}
