import BikeDomain
import DashboardCardSettings
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Dashboard card settings view model")
struct DashboardCardSettingsViewModelTests {
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

    @Test("Ignores attempts to hide configured Bike Lock")
    func keepsConfiguredBikeLockVisible() async {
        var settings = AppSettings()
        settings.setBikeLockSettings(
            .init(securityMode: .pin),
            forVIN: "FENRTEST000000001"
        )
        let repository = DashboardCardSettingsRepository(settings: settings)
        let capabilityStore = DashboardCardSettingsBikeLockCapabilityStore(state: .init(
            vehicleIdentifier: "FENRTEST000000001",
            isAvailable: true
        ))
        let viewModel = makeViewModel(
            repository: repository,
            capabilityStore: capabilityStore
        )
        viewModel.start()
        #expect(await waitUntil {
            viewModel.viewState.section(id: DashboardCardSectionID.bikeLock.rawValue) != nil
        })

        viewModel.setSectionVisibility(false, id: DashboardCardSectionID.bikeLock.rawValue)

        #expect(await repository.settings.dashboardCardConfiguration.section(id: .bikeLock).isVisible)
        #expect(await repository.saveCallCount == 0)
        viewModel.stop()
    }

    @Test("Saves section order and visibility immediately")
    func savesSectionChanges() async {
        let repository = DashboardCardSettingsRepository(saveDelay: .milliseconds(100))
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.sections.count == 6 })

        viewModel.setSectionOrder(ids: [
            DashboardCardSectionID.range.rawValue,
            DashboardCardSectionID.navigation.rawValue,
            DashboardCardSectionID.currentTrip.rawValue,
            DashboardCardSectionID.efficiency.rawValue,
            DashboardCardSectionID.systemHealth.rawValue,
            DashboardCardSectionID.rideDynamics.rawValue
        ])
        viewModel.setSectionVisibility(false, id: DashboardCardSectionID.efficiency.rawValue)

        #expect(viewModel.viewState.sections.first?.id == DashboardCardSectionID.range.rawValue)
        #expect(viewModel.viewState.section(id: DashboardCardSectionID.efficiency.rawValue)?.isVisible == false)
        #expect(await waitUntil { await repository.savedSettings.count == 1 })
        await Task.yield()
        #expect(viewModel.viewState.sections.first?.id == DashboardCardSectionID.range.rawValue)
        #expect(viewModel.viewState.section(id: DashboardCardSectionID.efficiency.rawValue)?.isVisible == false)
        #expect(await waitUntil {
            let configuration = await repository.settings.dashboardCardConfiguration
            return configuration.sections.map(\.id).first(where: { $0 != .bikeLock }) == .range
                && !configuration.section(id: .efficiency).isVisible
        })
        let savedSettings = await repository.savedSettings
        #expect(savedSettings.count == 2)
        #expect(savedSettings.first?.dashboardCardConfiguration.section(id: .efficiency).isVisible == true)
        #expect(savedSettings.last?.dashboardCardConfiguration.section(id: .efficiency).isVisible == false)
        viewModel.stop()
    }

    @Test("Reorders pages and refuses to hide the final visible page")
    func updatesPagesSafely() async {
        let repository = DashboardCardSettingsRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.sections.count == 6 })

        viewModel.setPageOrder(
            ids: [DashboardCardPageID.efficiencyTrend.rawValue, DashboardCardPageID.efficiencyLive.rawValue],
            sectionID: DashboardCardSectionID.efficiency.rawValue
        )
        viewModel.setPageVisibility(
            false,
            id: DashboardCardPageID.efficiencyLive.rawValue,
            sectionID: DashboardCardSectionID.efficiency.rawValue
        )
        viewModel.setPageVisibility(
            false,
            id: DashboardCardPageID.efficiencyTrend.rawValue,
            sectionID: DashboardCardSectionID.efficiency.rawValue
        )

        #expect(await waitUntil {
            let pages = await repository.settings.dashboardCardConfiguration
                .section(id: .efficiency).pages
            return pages.map(\.id) == [.efficiencyTrend, .efficiencyLive]
                && pages.filter(\.isVisible).map(\.id) == [.efficiencyTrend]
        })
        #expect(viewModel.viewState.section(id: DashboardCardSectionID.efficiency.rawValue)?
            .pages.first?.canHide == false)
        viewModel.stop()
    }

    @Test("Keeps one observation alive across nested settings screens")
    func sharesObservationLifecycle() async {
        let repository = DashboardCardSettingsRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.start()
        viewModel.start()
        #expect(await waitUntil { await repository.observerCount == 1 })

        viewModel.stop()
        var externalSettings = AppSettings()
        externalSettings.dashboardCardConfiguration.setSectionVisibility(false, id: .range)
        await repository.save(externalSettings)

        #expect(await waitUntil {
            viewModel.viewState.section(id: DashboardCardSectionID.range.rawValue)?.isVisible == false
        })
        #expect(await repository.observerCount == 1)

        viewModel.stop()
        #expect(await waitUntil { await repository.observerCount == 0 })
    }

    @Test("Accepts later repository changes after a duplicate save is skipped")
    func clearsDuplicateSaveConfirmation() async {
        var initialConfiguration = DashboardCardConfiguration()
        initialConfiguration.setSectionOrder([
            .range, .navigation, .currentTrip, .efficiency, .systemHealth, .rideDynamics
        ])
        let repository = DashboardCardSettingsRepository(
            settings: AppSettings(dashboardCardConfiguration: initialConfiguration)
        )
        let viewModel = makeViewModel(repository: repository)

        viewModel.setSectionOrder(ids: initialConfiguration.sections.map { $0.id.rawValue })
        #expect(await waitUntil { await repository.saveCallCount == 1 })

        var externalSettings = await repository.settings
        externalSettings.dashboardCardConfiguration.setSectionVisibility(false, id: .range)
        await repository.save(externalSettings)
        viewModel.start()

        #expect(await waitUntil {
            viewModel.viewState.section(id: DashboardCardSectionID.range.rawValue)?.isVisible == false
        })
        viewModel.stop()
    }

    private func makeViewModel(
        repository: DashboardCardSettingsRepository,
        capabilityStore: DashboardCardSettingsBikeLockCapabilityStore = .init()
    ) -> DashboardCardSettingsViewModel {
        DashboardCardSettingsViewModel(
            useCases: .init(
                loadSettings: .init(repository: repository),
                observeSettings: .init(repository: repository),
                saveSettings: .init(repository: repository)
            ),
            mapper: DashboardCardSettingsViewStateMapper(),
            bikeLockCapabilityStore: capabilityStore
        )
    }
}
