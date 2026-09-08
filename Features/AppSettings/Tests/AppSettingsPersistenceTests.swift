@testable import AppSettings
import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct AppSettingsPersistenceTests {
    @Test("Pending changes preserve external fields and reject old snapshots")
    func pendingChangesPreserveExternalFields() async {
        let fixture = AppSettingsViewModelFixture()
        await fixture.start()
        let model = fixture.viewModel
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        let original = await fixture.settingsRepository.snapshot
        await fixture.settingsRepository.blockNextUpdate()
        model.selectMeasurementSystem(id: "imperial")
        #expect(await waitUntil { await fixture.settingsRepository.isUpdateBlocked })
        model.setShowsCompassRing(true)
        var external = original.settings
        external.speedSource = .gps
        await fixture.settingsRepository.publish(external)
        #expect(await waitUntil { model.viewState.speedSource.selection.selectedID == "gps" })
        #expect(model.viewState.measurementSystem.selectedID == "imperial")
        #expect(model.viewState.navigationSettings.showsCompassRing)
        await fixture.settingsRepository.resumeUpdate()
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        await fixture.settingsRepository.publishSnapshot(original)
        #expect(await waitUntil { model.pendingSettings.confirmed?.revision == 3 })
        let saved = await fixture.settingsRepository.settings
        #expect(saved.speedSource == .gps)
        #expect(saved.measurementSystem == .imperial)
        #expect(saved.rideNavigation.showsCompassRing)
        await model.stopAndWait()
    }

    @Test("A failed setting rolls back while the next queued setting is saved")
    func failedSettingDoesNotBlockQueue() async {
        let fixture = AppSettingsViewModelFixture()
        await fixture.start()
        let model = fixture.viewModel
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        model.selectMeasurementSystem(id: "imperial")
        model.setShowsCompassRing(true)
        #expect(await waitUntil { model.pendingSettings.isEmpty && model.settingsSaveError != nil })
        #expect(model.viewState.measurementSystem.selectedID == "system")
        #expect(model.viewState.navigationSettings.showsCompassRing)
        model.dismissSettingsSaveError()
        #expect(model.settingsSaveError == nil)
        await model.stopAndWait()
    }

    @Test("Changing motorcycles discards pending changes from the previous motorcycle")
    func changingMotorcyclesDiscardsPendingChanges() async {
        let fixture = AppSettingsViewModelFixture()
        await fixture.start()
        let model = fixture.viewModel
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.settingsRepository.blockNextUpdate()
        model.selectMeasurementSystem(id: "imperial")
        #expect(await waitUntil { await fixture.settingsRepository.isUpdateBlocked })
        model.setShowsCompassRing(true)
        await fixture.settingsRepository.publish(AppSettings().scoped(toVIN: "FENRTEST000000002"))
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        await fixture.settingsRepository.resumeUpdate()
        #expect(await waitUntil { model.viewState.measurementSystem.selectedID == "system" })
        #expect(!model.viewState.navigationSettings.showsCompassRing)
        #expect(model.settingsSaveError == nil)
        await model.stopAndWait()
    }

}
