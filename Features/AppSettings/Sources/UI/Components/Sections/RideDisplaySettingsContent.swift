#if os(iOS)
import DesignSystem
import Foundation
import SwiftUI

struct RideDisplaySettingsContent: View {
    let progressBarMode: DashboardProgressBarSettingsViewState
    let bikeBatteryDisplayMode: AppSettingsSelectionViewState
    let deviceBatteryDisplayMode: AppSettingsSelectionViewState
    let temperatureDisplayMode: AppSettingsSelectionViewState
    let speedSource: SpeedSourceSettingsViewState
    let onSelectProgressBarMode: (String) -> Void
    let onSelectBikeBatteryDisplayMode: (String) -> Void
    let onSelectDeviceBatteryDisplayMode: (String) -> Void
    let onSelectTemperatureDisplayMode: (String) -> Void
    let onSelectSpeedSource: (String) -> Void
    let onRequestLocationAccess: () -> Void

    var body: some View {
        Section {
            selectionPicker(
                .appSettingsProgressBarPickerTitle,
                selection: progressBarMode.selection,
                onSelect: onSelectProgressBarMode
            )
            selectionPicker(
                .appSettingsBikeBatteryPickerTitle,
                selection: bikeBatteryDisplayMode,
                onSelect: onSelectBikeBatteryDisplayMode
            )
            selectionPicker(
                .appSettingsPhoneBatteryPickerTitle,
                selection: deviceBatteryDisplayMode,
                onSelect: onSelectDeviceBatteryDisplayMode
            )
        } header: {
            Text(.appSettingsDashboardPresentationHeader)
        } footer: {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(progressBarMode.description)
                Text(.appSettingsDashboardPresentationFooter)
            }
        }

        Section {
            selectionPicker(
                .appSettingsTemperaturesPickerTitle,
                selection: temperatureDisplayMode,
                onSelect: onSelectTemperatureDisplayMode
            )
        } header: {
            Text(.appSettingsTemperaturesSection)
        } footer: {
            Text(.appSettingsTemperaturesFooter)
        }

        Section {
            selectionPicker(
                .appSettingsSpeedSourcePickerTitle,
                selection: speedSource.selection,
                onSelect: onSelectSpeedSource
            )

            if let locationPermission = speedSource.locationPermission {
                LocationPermissionRow(
                    status: locationPermission,
                    onRequestAccess: onRequestLocationAccess
                )
            }
        } header: {
            Text(.appSettingsSpeedSectionHeader)
        } footer: {
            Text(speedSource.description)
        }
    }

    private func selectionPicker(
        _ title: LocalizedStringResource,
        selection: AppSettingsSelectionViewState,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Picker(
            title,
            selection: Binding(
                get: { selection.selectedID },
                set: { selectedID in onSelect(selectedID) }
            )
        ) {
            ForEach(selection.options) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }
}
#endif
