import BikeDomain
@testable import DashboardCardSettings
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Dashboard card settings view model")
struct DashboardCardSettingsViewModelTests {
    @Test("A failed card change rolls back and a later queued change is saved")
    func failedChangeDoesNotBlockLaterChange() async {
        let fixture = DashboardCardSettingsViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.repository.failNextUpdate(.persistenceFailed)
        model.setSectionVisibility(false, id: "efficiency")
        model.setSectionVisibility(false, id: "range")
        #expect(await waitUntil { model.pendingSettings.isEmpty && model.settingsSaveError != nil })
        #expect(model.viewState.section(id: "efficiency")?.isVisible == true)
        #expect(model.viewState.section(id: "range")?.isVisible == false)
        await model.stopAndWait()
    }

    @Test("A vehicle switch discards queued card changes and stale snapshots")
    func vehicleSwitchDiscardsPendingChanges() async {
        let fixture = DashboardCardSettingsViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        let original = await fixture.repository.snapshot
        await fixture.repository.blockNextSave()
        model.setSectionVisibility(false, id: "efficiency")
        await fixture.repository.waitForBlockedSave()
        model.setSectionVisibility(false, id: "range")
        await fixture.repository.save(AppSettings().scoped(toVIN: "FENRTEST000000002"))
        #expect(await waitUntil { model.pendingSettings.confirmed?.settings.vin == "FENRTEST000000002" })
        await fixture.repository.publishSnapshot(original)
        await fixture.repository.releaseBlockedSave()
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        #expect(model.viewState.section(id: "efficiency")?.isVisible == true)
        #expect(model.viewState.section(id: "range")?.isVisible == true)
        #expect(model.settingsSaveError == nil)
        #expect(await fixture.repository.savedSettings.isEmpty)
        await model.stopAndWait()
    }

    @Test("Ignores attempts to hide firmware-compatible Bike Lock")
    func keepsCompatibleBikeLockVisible() async {
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
        let fixture = DashboardCardSettingsViewModelFixture(
            repository: repository,
            capabilityStore: capabilityStore
        )
        let viewModel = fixture.viewModel
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
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
        let repository = DashboardCardSettingsRepository()
        await repository.blockNextSave()
        let fixture = DashboardCardSettingsViewModelFixture(repository: repository)
        let viewModel = fixture.viewModel
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        #expect(await waitUntil { viewModel.viewState.sections.count == DashboardCardSectionID.allCases.count })

        viewModel.setSectionOrder(ids: [
            DashboardCardSectionID.range.rawValue,
            DashboardCardSectionID.navigation.rawValue,
            DashboardCardSectionID.currentTrip.rawValue,
            DashboardCardSectionID.efficiency.rawValue,
            DashboardCardSectionID.systemHealth.rawValue,
            DashboardCardSectionID.rideDynamics.rawValue
        ])
        await repository.waitForBlockedSave()
        viewModel.setSectionVisibility(false, id: DashboardCardSectionID.efficiency.rawValue)

        #expect(viewModel.viewState.sections.first(where: { $0.id != DashboardCardSectionID.bikeLock.rawValue })?.id
            == DashboardCardSectionID.range.rawValue)
        #expect(viewModel.viewState.section(id: DashboardCardSectionID.efficiency.rawValue)?.isVisible == false)
        #expect(await repository.savedSettings.isEmpty)
        await repository.releaseBlockedSave()
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
        let fixture = DashboardCardSettingsViewModelFixture()
        let repository = fixture.repository
        let viewModel = fixture.viewModel
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        #expect(await waitUntil { viewModel.viewState.sections.count == DashboardCardSectionID.allCases.count })

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
        let fixture = DashboardCardSettingsViewModelFixture()
        let repository = fixture.repository
        let capabilityStore = fixture.capabilityStore
        let viewModel = fixture.viewModel

        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        #expect(await waitUntil {
            await repository.observerCount == 1 && capabilityStore.observerCount == 1
        })

        viewModel.stop()
        var externalSettings = AppSettings()
        externalSettings.dashboardCardConfiguration.setSectionVisibility(false, id: .range)
        await repository.save(externalSettings)

        #expect(await waitUntil {
            viewModel.viewState.section(id: DashboardCardSectionID.range.rawValue)?.isVisible == false
        })
        #expect(await repository.observerCount == 1)
        #expect(capabilityStore.observerCount == 1)

        viewModel.stop()
        #expect(await waitUntil {
            await repository.observerCount == 0 && capabilityStore.observerCount == 0
        })
    }

    @Test("Accepts later repository changes after a duplicate save is skipped")
    func clearsDuplicateSaveConfirmation() async {
        let repository = DashboardCardSettingsRepository()
        let fixture = DashboardCardSettingsViewModelFixture(repository: repository)
        let viewModel = fixture.viewModel
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        await repository.blockNextSave()
        viewModel.setSectionVisibility(false, id: "range")
        await repository.waitForBlockedSave()
        var externalSettings = await repository.settings
        externalSettings.dashboardCardConfiguration.setSectionVisibility(false, id: .range)
        await repository.save(externalSettings)
        await repository.releaseBlockedSave()
        #expect(await waitUntil { viewModel.pendingSettings.isEmpty })
        #expect(await repository.saveCallCount == 1)
        #expect(await repository.savedSettings.isEmpty)

        externalSettings.dashboardCardConfiguration.setSectionVisibility(true, id: .range)
        await repository.save(externalSettings)
        #expect(await waitUntil { viewModel.viewState.section(id: "range")?.isVisible == true })
        viewModel.stop()
    }

    @Test("Allows a pending save to finish after observation stops")
    func stopAllowsPendingSaveToFinish() async {
        let repository = DashboardCardSettingsRepository()
        await repository.blockNextSave()
        let fixture = DashboardCardSettingsViewModelFixture(repository: repository)
        let viewModel = fixture.viewModel
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        #expect(await waitUntil { viewModel.viewState.sections.count == DashboardCardSectionID.allCases.count })

        viewModel.setSectionVisibility(false, id: DashboardCardSectionID.range.rawValue)
        await repository.waitForBlockedSave()
        viewModel.stop()

        #expect(await repository.savedSettings.isEmpty)
        await repository.releaseBlockedSave()
        #expect(await waitUntil {
            await repository.settings.dashboardCardConfiguration.section(id: .range).isVisible == false
        })
        #expect(await repository.savedSettings.count == 1)
    }
}

extension DashboardCardSettingsViewModelTests {
    @Test("Settings can be reordered but hiding it never saves a configuration")
    func settingsCanMoveButCannotHide() async {
        let fixture = DashboardCardSettingsViewModelFixture()
        let viewModel = fixture.viewModel
        viewModel.start()
        #expect(await waitUntil { viewModel.pendingSettings.confirmed != nil })
        #expect(await waitUntil { viewModel.viewState.sections.last?.id == "settings" })
        viewModel.setSectionVisibility(false, id: "settings")
        #expect(await fixture.repository.saveCallCount == 0)
        #expect(viewModel.viewState.section(id: "settings")?.isVisible == true)
        viewModel.setSectionOrder(ids: ["settings"])
        #expect(await waitUntil {
            let configuration = await fixture.repository.settings.dashboardCardConfiguration
            return configuration.sections.first { $0.id != .bikeLock }?.id == .settings
        })
        viewModel.stop()
    }
}
