import SwiftUI

struct DashboardCardSectionDetailContent: View {
    let section: DashboardCardSectionRowViewData?
    let setPageOrder: ([String]) -> Void
    let setPageVisibility: (Bool, String) -> Void

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
    }

    private var pageRowsBinding: Binding<[DashboardCardPageRowViewData]> {
        .init(
            get: { section?.pages ?? [] },
            set: { setPageOrder($0.map(\.id)) }
        )
    }

    private func visibilityBinding(for page: DashboardCardPageRowViewData) -> Binding<Bool> {
        .init(
            get: {
                section?
                    .pages.first(where: { $0.id == page.id })?.isVisible ?? page.isVisible
            },
            set: { setPageVisibility($0, page.id) }
        )
    }
}
