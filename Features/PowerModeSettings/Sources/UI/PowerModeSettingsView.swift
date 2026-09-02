import SwiftUI

public struct PowerModeSettingsView: View {
    @ObservedObject private var viewModel: PowerModeSettingsViewModel

    public init(viewModel: PowerModeSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section(.powerModeSettingsBikeSection) {
                PowerModeStatusPanel(
                    connectionText: viewModel.viewState.connectionText,
                    capabilityText: viewModel.viewState.capabilityText,
                    statusText: viewModel.viewState.statusText,
                    statusIsError: viewModel.viewState.statusIsError
                )
            }

            Section(.powerModeSettingsMapSection) {
                PowerModeSelector(
                    maps: viewModel.viewState.maps,
                    select: viewModel.selectMap(index:)
                )
            }

            Section(.powerModeSettingsMapNameSection) {
                PowerModeNameEditor(
                    mapIndex: viewModel.viewState.selectedMapIndex,
                    currentName: viewModel.viewState.currentName,
                    maximumLength: viewModel.viewState.maximumNameLength,
                    isEnabled: viewModel.viewState.canEditName,
                    error: viewModel.viewState.nameError,
                    save: viewModel.saveName,
                    reset: viewModel.resetName
                )
            }

            Section {
                ForEach(viewModel.viewState.adjustments) { adjustment in
                    PowerModeAdjustmentRow(
                        state: adjustment,
                        commit: { value in
                            viewModel.updateAdjustment(id: adjustment.id, value: value)
                        }
                    )
                }
            } header: {
                Text(.powerModeSettingsConfigurationSection)
            } footer: {
                Text(.powerModeSettingsConfigurationFooter)
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
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
