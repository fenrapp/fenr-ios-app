import SwiftUI

private struct RideNavigationSummaryPreview: View {
    @State private var name = "A very long recorded ride name through mountains and coastline"

    var body: some View {
        RideNavigationSummaryPanel(
            state: RideNavigationViewState(
                screen: .summary,
                errorText: "The route could not be saved. You can still export the GPX file.",
                canSaveCompletedRoute: true,
                summaryTitle: "Trail complete",
                summaryDetail: "128.4 km · 4:12:08"
            ),
            routeName: $name,
            onSave: {},
            onRetrySave: {},
            onDiscardUnsaved: {},
            onExport: {},
            onClose: {}
        )
        .background(Color.black)
    }
}

#Preview("Summary · Error · Accessibility") {
    RideNavigationSummaryPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Summary · Regular") {
    RideNavigationSummaryPreview()
}
