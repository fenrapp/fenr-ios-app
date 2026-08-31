import SwiftUI

#Preview("Home · Long library") {
    RideNavigationHomePanel(
        state: RideNavigationViewState(
            savedRoutes: [
                RideNavigationRouteRow(
                    id: UUID(),
                    title: "A very long mountain route name that must remain readable",
                    detail: "128.4 km · 31 Aug 2026 at 18:00"
                ),
                RideNavigationRouteRow(
                    id: UUID(),
                    title: "Coastal exploration and forest return",
                    detail: "84.2 km · 30 Aug 2026 at 09:15"
                )
            ]
        ),
        onClose: {},
        onImport: {},
        onRecord: {},
        onSearchQueryChanged: { _ in },
        onSearch: {},
        onSelectSearchResult: { _ in },
        onOpenRoute: { _ in },
        onShareRoute: { _ in },
        onDeleteRoute: { _ in }
    )
    .background(Color.black)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Home · Error") {
    RideNavigationHomePanel(
        state: RideNavigationViewState(errorText: "Saved routes could not be loaded."),
        onClose: {},
        onImport: {},
        onRecord: {},
        onSearchQueryChanged: { _ in },
        onSearch: {},
        onSelectSearchResult: { _ in },
        onOpenRoute: { _ in },
        onShareRoute: { _ in },
        onDeleteRoute: { _ in }
    )
    .background(Color.black)
}
