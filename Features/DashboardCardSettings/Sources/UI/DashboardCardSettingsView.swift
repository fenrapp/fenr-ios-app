import SwiftUI

public struct DashboardCardSettingsView: View {
    @ObservedObject private var viewModel: DashboardCardSettingsViewModel

    public init(viewModel: DashboardCardSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                ForEach(viewModel.viewState.fixedCards) { card in
                    HStack(spacing: Constants.rowSpacing) {
                        DashboardCardRowLabel(
                            title: card.title,
                            detail: card.detail,
                            thumbnail: card.thumbnail
                        )
                        Spacer(minLength: Constants.minimumSpacer)
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Locked")
                    }
                    .moveDisabled(true)
                }
            } header: {
                Text("Always Visible")
            } footer: {
                Text("Speedometer always opens first. Charging appears automatically when the bike is charging.")
            }

            Section {
                ForEach(sectionRowsBinding, editActions: .move) { row in
                    let section = row.wrappedValue
                    HStack(spacing: Constants.rowSpacing) {
                        NavigationLink {
                            DashboardCardSectionDetailView(
                                viewModel: viewModel,
                                sectionID: section.id
                            )
                        } label: {
                            DashboardCardRowLabel(
                                title: section.title,
                                detail: section.detail,
                                thumbnail: section.thumbnail
                            )
                        }
                        DashboardCardVisibilityToggle(
                            title: section.title,
                            isEnabled: true,
                            isVisible: visibilityBinding(for: section)
                        )
                    }
                    .moveDisabled(false)
                    .accessibilityElement(children: .contain)
                }
            } header: {
                Text("Riding Cards")
            } footer: {
                Text("Drag while editing to change the vertical swipe order. Hidden sections keep their page settings.")
            }
        }
        .navigationTitle("Dashboard Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var sectionRowsBinding: Binding<[DashboardCardSectionRowViewData]> {
        .init(
            get: { viewModel.viewState.sections },
            set: { viewModel.setSectionOrder(ids: $0.map(\.id)) }
        )
    }

    private func visibilityBinding(for section: DashboardCardSectionRowViewData) -> Binding<Bool> {
        .init(
            get: { viewModel.viewState.section(id: section.id)?.isVisible ?? section.isVisible },
            set: { viewModel.setSectionVisibility($0, id: section.id) }
        )
    }

    private enum Constants {
        static let rowSpacing: CGFloat = 8
        static let minimumSpacer: CGFloat = 8
    }
}
