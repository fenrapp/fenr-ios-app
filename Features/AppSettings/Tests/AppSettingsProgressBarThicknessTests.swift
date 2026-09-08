@testable import AppSettings
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct AppSettingsProgressBarThicknessTests {
    @Test("Saves thickness, preserves it while hidden, and restores it for speed")
    func savesThicknessAcrossModes() async {
        let fixture = AppSettingsViewModelFixture()
        await fixture.start()
        let model = fixture.viewModel
        #expect(model.viewState.dashboardProgressBarMode.thickness?.selectedID == "regular")
        model.selectDashboardProgressBarThickness(id: "thick")
        #expect(model.viewState.dashboardProgressBarMode.thickness?.selectedID == "thick")
        model.selectDashboardProgressBarMode(id: "hidden")
        #expect(model.viewState.dashboardProgressBarMode.thickness == nil)
        model.selectDashboardProgressBarMode(id: "speed")
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        #expect(model.viewState.dashboardProgressBarMode.thickness?.selectedID == "thick")
        let saved = await fixture.settingsRepository.settings
        #expect(saved.dashboardProgressBarThickness == .thick)
        #expect(saved.dashboardProgressBarMode == .speed)
        await model.stopAndWait()
    }

    @Test("Failed thickness saves restore the previous selection and invalid IDs are ignored")
    func restoresFailedSelection() async {
        let fixture = AppSettingsViewModelFixture()
        await fixture.start()
        let model = fixture.viewModel
        model.selectDashboardProgressBarThickness(id: "invalid")
        #expect(model.pendingSettings.isEmpty)
        #expect(model.settingsSaveError == nil)
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        model.selectDashboardProgressBarThickness(id: "thick")
        #expect(await waitUntil { model.pendingSettings.isEmpty && model.settingsSaveError != nil })
        #expect(model.viewState.dashboardProgressBarMode.thickness?.selectedID == "regular")
        #expect(await fixture.settingsRepository.settings.dashboardProgressBarThickness == .regular)
        await model.stopAndWait()
    }
}
