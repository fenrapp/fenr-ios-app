#if os(iOS)
import SwiftUI

struct RideDisplaySettingsContent: View {
    let state: RideDisplayOverviewViewState
    let onNavigation: (AppSettingsNavigationEvent) -> Void

    var body: some View {
        Section {
            SettingsNavigationRow(
                icon: "rectangle.bottomthird.inset.filled", iconTint: .orange,
                title: .appSettingsProgressBarPickerTitle, detail: state.progressBar,
                accessibilityIdentifier: "settings.rideDisplay.progressBar",
                showsDetailBelowTitle: true,
                action: { onNavigation(.show(.rideProgressBar)) }
            )
            SettingsNavigationRow(
                icon: "battery.75percent", iconTint: .green,
                title: .appSettingsRideBatteryDisplayTitle, detail: state.batteryDisplay,
                accessibilityIdentifier: "settings.rideDisplay.batteryDisplay",
                showsDetailBelowTitle: true,
                action: { onNavigation(.show(.rideBatteryDisplay)) }
            )
            SettingsNavigationRow(
                icon: "gauge.with.dots.needle.50percent", iconTint: .purple,
                title: .appSettingsRideInformationTitle, detail: state.rideInformation,
                accessibilityIdentifier: "settings.rideDisplay.information",
                showsDetailBelowTitle: true,
                action: { onNavigation(.show(.rideInformation)) }
            )
            SettingsNavigationRow(
                icon: "speedometer", iconTint: .blue,
                title: .appSettingsSpeedSectionHeader, detail: state.speed,
                accessibilityIdentifier: "settings.rideDisplay.speed",
                showsDetailBelowTitle: true,
                action: { onNavigation(.show(.rideSpeed)) }
            )
        }
    }
}
#endif
