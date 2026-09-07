import DesignSystem
import SwiftUI

public struct PowerModeSettingsView: View {
    @ObservedObject private var viewModel: PowerModeSettingsViewModel
    private let isPresentationActive: Bool
    @State private var isNameEditorPresented = false

    public init(
        viewModel: PowerModeSettingsViewModel,
        isPresentationActive: Bool = true
    ) {
        self.viewModel = viewModel
        self.isPresentationActive = isPresentationActive
    }

    public var body: some View {
        List {
            Section {
                PowerModeStatusPanel(
                    status: viewModel.viewState.status,
                    canRetry: viewModel.viewState.statusIsError
                        && viewModel.viewState.canRefresh,
                    retry: viewModel.refresh
                )
            }

            Section(.powerModeSettingsMapSection) {
                PowerModeSelector(
                    maps: viewModel.viewState.maps,
                    select: viewModel.selectMap(index:)
                )
                mapNameButton
            }

            ForEach(viewModel.viewState.controlGroups) { group in
                Section {
                    ForEach(group.adjustments) { adjustment in
                        PowerModeAdjustmentRow(
                            state: adjustment,
                            commit: { value in
                                viewModel.updateAdjustment(id: adjustment.id, value: value)
                            }
                        )
                    }
                } header: {
                    Text(group.title)
                } footer: {
                    Text(group.detail)
                }
            }
        }
        .navigationTitle(Text(.powerModeSettingsTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!viewModel.viewState.canRefresh)
                .accessibilityLabel(.powerModeSettingsRefreshAccessibility)
            }
        }
        .sheet(isPresented: $isNameEditorPresented) {
            PowerModeNameEditor(
                mapIndex: viewModel.viewState.selectedMapIndex,
                currentName: viewModel.viewState.currentName,
                maximumLength: viewModel.viewState.maximumNameLength,
                isEnabled: viewModel.viewState.canEditName && !viewModel.viewState.isSavingName,
                error: viewModel.viewState.nameError,
                save: viewModel.saveName,
                reset: viewModel.resetName
            )
        }
        .onChange(of: viewModel.viewState.nameSaveCompletionID) {
            isNameEditorPresented = false
        }
        .task { synchronizePresentation() }
        .onChange(of: isPresentationActive) { synchronizePresentation() }
        .onDisappear { viewModel.setPresentationActive(false) }
    }

    private func synchronizePresentation() {
        viewModel.setPresentationActive(isPresentationActive)
    }

    private var mapNameButton: some View {
        Button {
            isNameEditorPresented = true
        } label: {
            HStack(spacing: DesignSpace.small) {
                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                    Text(.powerModeSettingsMapNameSection)
                        .foregroundStyle(DesignColor.primaryText)
                    Text(selectedMapTitle)
                        .font(.subheadline)
                        .foregroundStyle(DesignColor.secondaryText)
                }
                Spacer(minLength: DesignSpace.small)
                Text(.powerModeSettingsEditName)
                    .font(.callout.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignColor.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Constants.minimumControlSize)
        }
        .disabled(!viewModel.viewState.canEditName || viewModel.viewState.isSavingName)
        .accessibilityHint(.powerModeSettingsEditNameHint)
        .accessibilityIdentifier("powerModes.editName")
    }

    private var selectedMapTitle: String {
        viewModel.viewState.maps
            .first(where: \PowerModeMapViewData.isSelected)?
            .title
            ?? String(localized: .powerModeSettingsMapAccessibility(
                viewModel.viewState.selectedMapIndex + 1
            ))
    }

    private enum Constants {
        static let minimumControlSize: CGFloat = 44
    }
}
