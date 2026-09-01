#if os(iOS)
import SwiftUI

struct RideDashboardSettingsSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let progressBarMode: DashboardProgressBarSettingsViewState
    let deviceBatteryDisplayMode: AppSettingsSelectionViewState
    let showsTemperatures: Bool
    let speedSource: SpeedSourceSettingsViewState
    let onSelectProgressBarMode: (String) -> Void
    let onSelectDeviceBatteryDisplayMode: (String) -> Void
    let onSetShowsTemperatures: (Bool) -> Void
    let onSelectSpeedSource: (String) -> Void
    let onRequestLocationAccess: () -> Void
    let onOpenDashboardCards: () -> Void

    var body: some View {
        Section("Ride dashboard") {
            Picker("Progress bar", selection: progressBarModeBinding) {
                ForEach(progressBarMode.selection.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            Text(progressBarMode.description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            phoneBatteryPicker

            Text("Controls how the phone battery appears beside the dashboard clock.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Battery and inverter temperatures", isOn: showsTemperaturesBinding)

            Text("Shows available thermal readings on the ride dashboard.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Speed source", selection: speedSourceBinding) {
                ForEach(speedSource.selection.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            Text(speedSource.description)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let locationPermission = speedSource.locationPermission {
                LocationPermissionRow(
                    status: locationPermission,
                    onRequestAccess: onRequestLocationAccess
                )
            }

            SettingsNavigationRow(
                icon: "rectangle.stack.fill",
                title: "Dashboard cards",
                detail: "Choose their order and visibility",
                accessibilityIdentifier: "settings.dashboardCards",
                action: onOpenDashboardCards
            )
        }
    }

    private var progressBarModeBinding: Binding<String> {
        .init(
            get: { progressBarMode.selection.selectedID },
            set: { onSelectProgressBarMode($0) }
        )
    }

    @ViewBuilder
    private var phoneBatteryPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            phoneBatteryPickerContent
                .pickerStyle(.inline)
        } else {
            phoneBatteryPickerContent
                .pickerStyle(.menu)
        }
    }

    private var phoneBatteryPickerContent: some View {
        Picker("Phone battery", selection: deviceBatteryDisplayModeBinding) {
            ForEach(deviceBatteryDisplayMode.options) { option in
                Text(option.title)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .tag(option.id)
            }
        }
    }

    private var deviceBatteryDisplayModeBinding: Binding<String> {
        .init(
            get: { deviceBatteryDisplayMode.selectedID },
            set: { onSelectDeviceBatteryDisplayMode($0) }
        )
    }

    private var showsTemperaturesBinding: Binding<Bool> {
        .init(
            get: { showsTemperatures },
            set: { onSetShowsTemperatures($0) }
        )
    }

    private var speedSourceBinding: Binding<String> {
        .init(
            get: { speedSource.selection.selectedID },
            set: { onSelectSpeedSource($0) }
        )
    }
}
#endif
