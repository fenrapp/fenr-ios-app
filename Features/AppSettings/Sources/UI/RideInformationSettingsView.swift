#if os(iOS)
import SwiftUI

struct RideInformationSettingsView: View {
    let showsBikeHours: Bool
    let temperatures: AppSettingsSelectionViewState
    let onSetShowsBikeHours: (Bool) -> Void
    let onSelectTemperatures: (String) -> Void

    var body: some View {
        Form {
            Section {
                Toggle(.appSettingsShowBikeHours, isOn: Binding(
                    get: { showsBikeHours }, set: { onSetShowsBikeHours($0) }
                ))
                .accessibilityIdentifier("settings.bikeHours")
            }
            Section {
                SettingsSelectionPicker(
                    title: .appSettingsTemperaturesPickerTitle,
                    selection: temperatures, onSelect: onSelectTemperatures
                )
            } header: {
                Text(.appSettingsTemperaturesSection)
            } footer: {
                Text(.appSettingsTemperaturesFooter)
            }
        }
        .navigationTitle(Text(.appSettingsRideInformationTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
