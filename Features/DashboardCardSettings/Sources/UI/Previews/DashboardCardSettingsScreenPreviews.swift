import SwiftUI

#if DEBUG
#Preview("Dashboard cards - reorder") {
    NavigationStack {
        DashboardCardOrderPreview()
    }
}

#Preview("Dashboard cards - accessibility") {
    NavigationStack {
        DashboardCardOrderPreview()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Section detail - reorder and last visible card") {
    NavigationStack {
        DashboardPageOrderPreview()
    }
}

private struct DashboardCardOrderPreview: View {
    @State private var sections = DashboardCardSettingsPreviewData.sections

    var body: some View {
        DashboardCardSettingsContent(
            state: .init(fixedCards: DashboardCardSettingsPreviewData.fixedCards, sections: sections),
            setSectionOrder: { ids in sections = ids.compactMap { id in sections.first { $0.id == id } } },
            setSectionVisibility: { _, _ in },
            selectSection: { _ in }
        )
        .environment(\.editMode, .constant(.active))
    }
}

private struct DashboardPageOrderPreview: View {
    @State private var pages = DashboardCardSettingsPreviewData.pages

    var body: some View {
        DashboardCardSectionDetailContent(
            section: DashboardCardSettingsPreviewData.rideData(pages: pages),
            setPageOrder: { ids in pages = ids.compactMap { id in pages.first { $0.id == id } } },
            setPageVisibility: { _, _ in }
        )
        .environment(\.editMode, .constant(.active))
    }
}
#endif
