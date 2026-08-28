import AppSettings
import BikeDomain
import EnvironmentDomain
import SettingsDomain
import Testing

@Suite("Power modes settings navigation")
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

        #expect(state.powerModes.detail == "5 maps · 1 custom name")
    }

    @Test("Uses the configured-map fallback without local names")
    func mapsFallbackSummary() {
        let state = AppSettingsViewStateMapper().map(
            settings: .init(),
            locationAuthorizationStatus: .notDetermined,
            profile: .init(vin: vin)
        )

        #expect(state.powerModes.detail == "5 maps configured")
    }
}
