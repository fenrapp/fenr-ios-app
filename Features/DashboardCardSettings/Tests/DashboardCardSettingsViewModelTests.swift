import DashboardCardSettings
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Dashboard card settings view model")
struct DashboardCardSettingsViewModelTests {
    @Test("Publishes fixed cards and configurable sections")
    func publishesPresentationState() {
        let state = DashboardCardSettingsViewStateMapper().map(configuration: .init())

        #expect(state.fixedCards.map(\.title) == ["Speedometer", "Charging"])
        #expect(state.sections.map(\.title) == [
            "Current Trip", "Efficiency", "Range", "System Health", "Ride Dynamics"
        ])
        #expect(state.sections.first?.detail == "2 of 2 cards visible · Current Trip first")
    }

    @Test("Saves section order and visibility immediately")
    func savesSectionChanges() async {
        let repository = DashboardCardSettingsRepository(saveDelay: .milliseconds(100))
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { viewModel.viewState.sections.count == 5 })

        viewModel.setSectionOrder(ids: [
            DashboardCardSectionID.range.rawValue,
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
            return configuration.sections.map(\.id).first == .range
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
        #expect(await waitUntil { viewModel.viewState.sections.count == 5 })

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
            .range, .currentTrip, .efficiency, .systemHealth, .rideDynamics
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
        repository: DashboardCardSettingsRepository
    ) -> DashboardCardSettingsViewModel {
        DashboardCardSettingsViewModel(
            useCases: .init(
                loadSettings: .init(repository: repository),
                observeSettings: .init(repository: repository),
                saveSettings: .init(repository: repository)
            ),
            mapper: DashboardCardSettingsViewStateMapper()
        )
    }
}
