#if os(iOS)
import SwiftUI

struct RideBatteryDisplaySettingsView: View {
    let bikeBattery: AppSettingsSelectionViewState
    let phoneBattery: AppSettingsSelectionViewState
    let onSelectBikeBattery: (String) -> Void
    let onSelectPhoneBattery: (String) -> Void

    var body: some View {
        Form {
            Section {
                SettingsSelectionPicker(
                    title: .appSettingsBikeBatteryPickerTitle,
                    selection: bikeBattery, onSelect: onSelectBikeBattery
                )
            } footer: {
                Text(.appSettingsDashboardPresentationFooter)
            }
            Section {
                SettingsSelectionPicker(
                    title: .appSettingsPhoneBatteryPickerTitle,
                    selection: phoneBattery, onSelect: onSelectPhoneBattery
                )
                .accessibilityIdentifier("settings.phoneBattery")
            }
        }
        .navigationTitle(Text(.appSettingsRideBatteryDisplayTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
