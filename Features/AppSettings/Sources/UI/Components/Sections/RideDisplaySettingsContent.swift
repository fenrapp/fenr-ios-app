#if os(iOS)
import DesignSystem
import Foundation
import SwiftUI

struct RideDisplaySettingsContent: View {
    let progressBarMode: DashboardProgressBarSettingsViewState
    let bikeBatteryDisplayMode: AppSettingsSelectionViewState
    let deviceBatteryDisplayMode: AppSettingsSelectionViewState
    let showsTemperatures: Bool
    let speedSource: SpeedSourceSettingsViewState
    let onSelectProgressBarMode: (String) -> Void
    let onSelectBikeBatteryDisplayMode: (String) -> Void
    let onSelectDeviceBatteryDisplayMode: (String) -> Void
    let onSetShowsTemperatures: (Bool) -> Void
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
            Toggle(.appSettingsTemperaturesToggle, isOn: showsTemperaturesBinding)
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
                set: onSelect
            )
        ) {
            ForEach(selection.options) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
    }

    private var showsTemperaturesBinding: Binding<Bool> {
        .init(
            get: { showsTemperatures },
            set: onSetShowsTemperatures
        )
    }
}
#endif
