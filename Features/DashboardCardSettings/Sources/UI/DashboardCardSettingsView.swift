import DesignSystem
import SwiftUI

public struct DashboardCardSettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var viewModel: DashboardCardSettingsViewModel

    public init(viewModel: DashboardCardSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                ForEach(viewModel.viewState.fixedCards) { card in
                    fixedRow(card)
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
                    DashboardCardVisibilityRow(
                        title: section.title,
                        isEnabled: section.isVisibilityEnabled,
                        disabledHint: section.disabledVisibilityHint,
                        isVisible: visibilityBinding(for: section)
                    ) {
                        sectionLabel(section)
                    }
                    .moveDisabled(false)
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

    @ViewBuilder
    private func fixedRow(_ card: DashboardCardFixedRowViewData) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                fixedRowLabel(card)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer(minLength: DesignSpace.extraSmall)
                    fixedRowLock
                }
            }
        } else {
            HStack(spacing: DesignSpace.extraSmall) {
                fixedRowLabel(card)
                Spacer(minLength: DesignSpace.extraSmall)
                fixedRowLock
            }
        }
    }

    private func fixedRowLabel(_ card: DashboardCardFixedRowViewData) -> some View {
        DashboardCardRowLabel(
            title: card.title,
            detail: card.detail,
            thumbnail: card.thumbnail
        )
    }

    private var fixedRowLock: some View {
        Image(systemName: "lock.fill")
            .foregroundStyle(.secondary)
            .accessibilityLabel("Locked")
    }

    @ViewBuilder
    private func sectionLabel(_ section: DashboardCardSectionRowViewData) -> some View {
        if section.pages.isEmpty {
            DashboardCardRowLabel(
                title: section.title,
                detail: section.detail,
                thumbnail: section.thumbnail
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
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
        }
    }

}
