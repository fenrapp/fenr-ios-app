#if os(iOS)
import SwiftUI

struct RideSpeedSettingsView: View {
    let state: SpeedSourceSettingsViewState
    let onSelect: (String) -> Void
    let onRequestLocationAccess: () -> Void

    var body: some View {
        Form {
            Section {
                SettingsSelectionPicker(
                    title: .appSettingsSpeedSourcePickerTitle,
                    selection: state.selection, onSelect: onSelect
                )
                if let locationPermission = state.locationPermission {
                    LocationPermissionRow(status: locationPermission, onRequestAccess: onRequestLocationAccess)
                }
            } footer: {
                Text(state.description)
            }
        }
        .navigationTitle(Text(.appSettingsSpeedSectionHeader))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
