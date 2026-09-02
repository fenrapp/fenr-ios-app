import SwiftUI

struct DashboardCardSectionDetailView: View {
    @ObservedObject var viewModel: DashboardCardSettingsViewModel
    let sectionID: String

    var body: some View {
        List {
            Section {
                ForEach(pageRowsBinding, editActions: .move) { row in
                    let page = row.wrappedValue
                    DashboardCardVisibilityRow(
                        title: page.title,
                        isEnabled: page.canHide,
                        disabledHint: .dashboardCardSettingsAtLeastOneVisibleHint,
                        isVisible: visibilityBinding(for: page)
                    ) {
                        DashboardCardRowLabel(
                            title: page.title,
                            detail: page.isVisible
                                ? .dashboardCardSettingsVisibleStatus
                                : .dashboardCardSettingsHiddenStatus,
                            thumbnail: page.thumbnail
                        )
                    }
                    .moveDisabled(false)
                }
            } header: {
                Text(.dashboardCardSettingsCardsHeader)
            } footer: {
                Text(.dashboardCardSettingsCardsFooter)
            }
        }
        .navigationTitle(Text(section?.title ?? .dashboardCardSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var section: DashboardCardSectionRowViewData? {
        viewModel.viewState.section(id: sectionID)
    }

    private var pageRowsBinding: Binding<[DashboardCardPageRowViewData]> {
        .init(
            get: { section?.pages ?? [] },
            set: { viewModel.setPageOrder(ids: $0.map(\.id), sectionID: sectionID) }
        )
    }

    private func visibilityBinding(for page: DashboardCardPageRowViewData) -> Binding<Bool> {
        .init(
            get: {
                viewModel.viewState.section(id: sectionID)?
                    .pages.first(where: { $0.id == page.id })?.isVisible ?? page.isVisible
            },
            set: { viewModel.setPageVisibility($0, id: page.id, sectionID: sectionID) }
        )
    }
}
