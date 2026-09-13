import AppSettings
import Foundation
import SettingsDomain
import Testing

@Suite("Ride display overview summaries")
struct RideDisplayOverviewMapperTests {
    @Test("A hidden bar omits its saved thickness")
    func hiddenBar() {
        var settings = AppSettings()
        settings.dashboardProgressBarMode = .hidden
        settings.dashboardProgressBarThickness = .thick
        let state = AppSettingsViewStateMapper().map(settings: settings, locationAuthorizationStatus: .notDetermined)
        #expect(String(localized: state.rideDisplayOverview.progressBar) == "Hidden")
        #expect(state.dashboardProgressBarMode.thickness == nil)
    }

    @Test("All four summaries describe the current selections")
    func currentSelections() {
        var settings = AppSettings()
        settings.dashboardProgressBarMode = .speed
        settings.dashboardProgressBarThickness = .thick
        settings.dashboardBatteryIndicatorMode = .estimatedRange
        settings.dashboardDeviceBatteryDisplayMode = .hidden
        settings.showsBikeHours = true
        settings.dashboardTemperatureDisplayMode = .both
        settings.speedSource = .hybrid
        let state = AppSettingsViewStateMapper().map(settings: settings, locationAuthorizationStatus: .authorized)
        #expect(String(localized: state.rideDisplayOverview.progressBar) == "Speed \u{00B7} Thick")
        #expect(String(localized: state.rideDisplayOverview.batteryDisplay).contains("Phone: Hidden"))
        #expect(String(localized: state.rideDisplayOverview.rideInformation)
            == "Bike hours on \u{00B7} Temperatures: Both")
        #expect(String(localized: state.rideDisplayOverview.speed) == "GPS+")
    }
}
