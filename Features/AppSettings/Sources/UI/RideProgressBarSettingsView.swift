#if os(iOS)
import SwiftUI

struct RideProgressBarSettingsView: View {
    let state: DashboardProgressBarSettingsViewState
    let onSelectMode: (String) -> Void
    let onSelectThickness: (String) -> Void

    var body: some View {
        Form {
            Section {
                SettingsSelectionPicker(
                    title: .appSettingsProgressBarPickerTitle,
                    selection: state.selection, onSelect: onSelectMode
                )
                if let thickness = state.thickness {
                    SettingsSelectionPicker(
                        title: .appSettingsProgressBarThicknessTitle,
                        selection: thickness, onSelect: onSelectThickness
                    )
                    .accessibilityIdentifier("settings.progressBarThickness")
                }
            } footer: {
                Text(state.description)
            }
        }
        .navigationTitle(Text(.appSettingsProgressBarPickerTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
