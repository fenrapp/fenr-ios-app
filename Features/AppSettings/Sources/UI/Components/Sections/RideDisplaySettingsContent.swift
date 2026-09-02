#if os(iOS)
import DesignSystem
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
                "Progress Bar",
                selection: progressBarMode.selection,
                onSelect: onSelectProgressBarMode
            )
            selectionPicker(
                "Bike Battery",
                selection: bikeBatteryDisplayMode,
                onSelect: onSelectBikeBatteryDisplayMode
            )
            selectionPicker(
                "Phone Battery",
                selection: deviceBatteryDisplayMode,
                onSelect: onSelectDeviceBatteryDisplayMode
            )
            Toggle("Battery and Inverter Temperatures", isOn: showsTemperaturesBinding)
        } header: {
            Text("Dashboard Presentation")
        } footer: {
            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                Text(progressBarMode.description)
                Text(
                    "Estimated range falls back to battery percentage until range data is available. "
                        + "Temperature readings appear only when reported by the bike."
                )
            }
        }

        Section {
            selectionPicker(
                "Speed Source",
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
            Text("Speed")
        } footer: {
            Text(speedSource.description)
        }
    }

    private func selectionPicker(
        _ title: String,
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
