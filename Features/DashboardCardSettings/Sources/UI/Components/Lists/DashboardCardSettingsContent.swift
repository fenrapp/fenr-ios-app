import DesignSystem
import SwiftUI

struct DashboardCardSettingsContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: DashboardCardSettingsViewState
    let setSectionOrder: ([String]) -> Void
    let setSectionVisibility: (Bool, String) -> Void
    let selectSection: (String) -> Void

    var body: some View {
        List {
            Section {
                ForEach(state.fixedCards) { card in
                    fixedRow(card)
                    .moveDisabled(true)
                }
            } header: {
                Text(.dashboardCardSettingsAlwaysVisibleHeader)
            } footer: {
                Text(.dashboardCardSettingsAlwaysVisibleFooter)
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
                Text(.dashboardCardSettingsRidingCardsHeader)
            } footer: {
                Text(.dashboardCardSettingsRidingCardsFooter)
            }
        }
        .navigationTitle(Text(.dashboardCardSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private var sectionRowsBinding: Binding<[DashboardCardSectionRowViewData]> {
        .init(
            get: { state.sections },
            set: { setSectionOrder($0.map(\.id)) }
        )
    }

    private func visibilityBinding(for section: DashboardCardSectionRowViewData) -> Binding<Bool> {
        .init(
            get: { state.section(id: section.id)?.isVisible ?? section.isVisible },
            set: { setSectionVisibility($0, section.id) }
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
            .accessibilityLabel(.dashboardCardSettingsLockedLabel)
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
            Button {
                selectSection(section.id)
            } label: {
                HStack {
                    DashboardCardRowLabel(
                        title: section.title,
                        detail: section.detail,
                        thumbnail: section.thumbnail
                    )
                    Spacer(minLength: DesignSpace.extraSmall)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
        }
    }

}
