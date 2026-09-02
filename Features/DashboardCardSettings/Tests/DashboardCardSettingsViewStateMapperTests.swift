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

        #expect(state.fixedCards.map { String(localized: $0.title) } == ["Speedometer", "Charging"])
        #expect(state.sections.map { String(localized: $0.title) } == [
            "Ride Navigation", "Current Trip", "Efficiency", "Range", "System Health", "Ride Dynamics"
        ])
        #expect(state.sections.first.map { String(localized: $0.detail) }
            == "Open ride navigation from the dashboard")
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

    @Test("Pluralizes the visible card count")
    func pluralizesVisibleCardCount() {
        var settings = AppSettings()
        settings.dashboardCardConfiguration.setPageVisibility(
            false,
            id: .efficiencyTrend,
            sectionID: .efficiency
        )

        let state = DashboardCardSettingsViewStateMapper().map(
            settings: settings,
            bikeLockCapability: .init()
        )
        let efficiency = state.section(id: DashboardCardSectionID.efficiency.rawValue)

        #expect(efficiency.map { String(localized: $0.detail) }
            == "1 of 2 card visible · Live Efficiency first")
    }
}
