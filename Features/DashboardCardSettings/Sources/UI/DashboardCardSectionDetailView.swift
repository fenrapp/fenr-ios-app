import SwiftUI

struct DashboardCardSectionDetailView: View {
    @ObservedObject var viewModel: DashboardCardSettingsViewModel
    let sectionID: String

    var body: some View {
        List {
            Section {
                ForEach(pageRowsBinding, editActions: .move) { row in
                    let page = row.wrappedValue
                    HStack(spacing: Constants.rowSpacing) {
                        DashboardCardRowLabel(
                            title: page.title,
                            detail: page.isVisible ? "Visible" : "Hidden",
                            thumbnail: page.thumbnail
                        )
                        Spacer(minLength: Constants.minimumSpacer)
                        DashboardCardVisibilityToggle(
                            title: page.title,
                            isEnabled: page.canHide,
                            isVisible: visibilityBinding(for: page)
                        )
                    }
                    .moveDisabled(false)
                    .accessibilityElement(children: .contain)
                }
            } header: {
                Text("Cards")
            } footer: {
                Text(
                    "Drag cards while editing to set their swipe order. "
                        + "The first visible card opens first. At least one card must remain visible."
                )
            }
        }
        .navigationTitle(section?.title ?? "Dashboard Cards")
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

    private enum Constants {
        static let rowSpacing: CGFloat = 8
        static let minimumSpacer: CGFloat = 8
    }
}
