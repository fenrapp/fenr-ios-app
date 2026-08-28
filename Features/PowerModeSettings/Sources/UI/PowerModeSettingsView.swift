import SwiftUI

public struct PowerModeSettingsView: View {
    @ObservedObject private var viewModel: PowerModeSettingsViewModel

    public init(viewModel: PowerModeSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("Bike") {
                PowerModeStatusPanel(
                    connectionText: viewModel.viewState.connectionText,
                    capabilityText: viewModel.viewState.capabilityText,
                    statusText: viewModel.viewState.statusText,
                    statusIsError: viewModel.viewState.statusIsError
                )
            }

            Section("Map") {
                PowerModeSelector(
                    maps: viewModel.viewState.maps,
                    select: viewModel.selectMap(index:)
                )
            }

            Section("Map name") {
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
                Text("Configuration")
            } footer: {
                Text(
                    "Each map value is sent only after a confirmed read and its own no-op safety check."
                )
            }
        }
        .navigationTitle("Power Modes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: viewModel.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh power modes")
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
