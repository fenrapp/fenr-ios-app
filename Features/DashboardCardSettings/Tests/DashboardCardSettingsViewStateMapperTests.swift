import BikeDomain
import DashboardCardSettings
import SettingsDomain
import Testing

@Suite("Dashboard card settings view-state mapper")
struct DashboardCardSettingsViewStateMapperTests {
    @Test("Publishes fixed cards and configurable sections")
    func publishesPresentationState() {
        let state = DashboardCardSettingsViewStateMapper().map(
            settings: .init(),
            bikeLockCapability: .init()
        )

        #expect(state.fixedCards.map(\.title) == ["Speedometer", "Charging"])
        #expect(state.sections.map(\.title) == [
            "Ride Navigation", "Current Trip", "Efficiency", "Range", "System Health", "Ride Dynamics"
        ])
        #expect(state.sections.first?.detail == "Open ride navigation from the dashboard")
    }

    @Test("Publishes compatible Bike Lock and prevents hiding configured protection")
    func publishesBikeLockAvailability() {
        var settings = AppSettings()
        let available = BikeLockCapabilityState(
            vehicleIdentifier: "FENRTEST000000001",
            isAvailable: true
        )
        let mapper = DashboardCardSettingsViewStateMapper()

        let unconfigured = mapper.map(settings: settings, bikeLockCapability: available)
        #expect(unconfigured.sections.first?.id == DashboardCardSectionID.bikeLock.rawValue)
        #expect(unconfigured.sections.first?.isVisibilityEnabled == true)

        settings.setBikeLockSettings(
            .init(securityMode: .pin),
            forVIN: "FENRTEST000000001"
        )
        settings.dashboardCardConfiguration.setSectionVisibility(false, id: .bikeLock)
        let configured = mapper.map(settings: settings, bikeLockCapability: available)
        let bikeLock = configured.section(id: DashboardCardSectionID.bikeLock.rawValue)
        #expect(bikeLock?.isVisible == true)
        #expect(bikeLock?.isVisibilityEnabled == false)
    }
}
