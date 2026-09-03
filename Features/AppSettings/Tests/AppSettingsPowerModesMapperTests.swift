import AppSettings
import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing

@Suite("Settings navigation summaries")
struct AppSettingsPowerModesMapperTests {
    private let vin = "FENRTEST000000001"

    @Test("Summarizes all five maps and local names for the active bike")
    func mapsSummary() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(try PowerModeName("ECO"), forVIN: vin, mapIndex: 0)

        let state = AppSettingsViewStateMapper().map(
            settings: settings,
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: vin)
        )

        #expect(String(localized: state.powerModes.detail) == "5 maps · 1 custom name")
    }

    @Test("Pluralizes multiple local map names")
    func mapsSummaryPlural() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(try PowerModeName("ECO"), forVIN: vin, mapIndex: 0)
        try settings.setPowerModeName(try PowerModeName("RACE"), forVIN: vin, mapIndex: 1)

        let state = AppSettingsViewStateMapper().map(
            settings: settings,
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: vin)
        )

        #expect(String(localized: state.powerModes.detail) == "5 maps · 2 custom names")
    }

    @Test("Uses the configured-map fallback without local names")
    func mapsFallbackSummary() {
        let state = AppSettingsViewStateMapper().map(
            settings: .init(),
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: vin)
        )

        #expect(String(localized: state.powerModes.detail) == "5 maps configured")
    }

    @Test("Summarizes ride display selections")
    func rideDisplaySummary() {
        let settings = AppSettings(
            speedSource: .hybrid,
            dashboardProgressBarMode: .speed
        )

        let state = AppSettingsViewStateMapper().map(
            settings: settings,
            locationAuthorizationStatus: .notDetermined
        )

        #expect(String(localized: state.rideDisplay.detail) == "Speed · GPS+")
    }

    @Test("Summarizes visible dashboard sections")
    func dashboardCardsSummary() {
        var configuration = DashboardCardConfiguration()
        configuration.setSectionVisibility(false, id: .efficiency)
        let settings = AppSettings(dashboardCardConfiguration: configuration)

        let state = AppSettingsViewStateMapper().map(
            settings: settings,
            locationAuthorizationStatus: .notDetermined
        )

        #expect(String(localized: state.dashboardCards.detail) == "6 visible")
    }

    @Test("Hides the manual bike model fallback after confirmed Alpha detection")
    func hidesDerivedBikeModel() {
        let detected = AppSettingsViewStateMapper().map(
            settings: .init(),
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: vin, alphaEvidence: [.powerAboveStandard])
        )
        let fallback = AppSettingsViewStateMapper().map(
            settings: .init(),
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: vin)
        )

        #expect(!detected.isBikeModelSelectionVisible)
        #expect(fallback.isBikeModelSelectionVisible)
    }
}
