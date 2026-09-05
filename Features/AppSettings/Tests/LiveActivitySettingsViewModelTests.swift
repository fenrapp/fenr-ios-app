import AppSettings
import Foundation
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("Live Activity settings presentation")
struct LiveActivitySettingsViewModelTests {
    @Test("Maps both activities and the hidden summary")
    func mapsPreferences() {
        let state = AppSettingsViewStateMapper().map(
            settings: .init(liveActivities: .init(isEnabled: false, ridingDetailLevel: .summary)),
            locationAuthorizationStatus: .notDetermined
        ).liveActivities
        #expect(!state.isEnabled)
        #expect(String(localized: state.summary) == "Hidden")
        #expect(state.activities.map(\.id) == ["riding", "charging"])
        #expect(state.activities.first?.presentation.selectedID == "summary")
        #expect(state.activities.last?.presentation.selectedID == "detailed")
    }

    @Test("Saves independent selections and ignores unknown IDs")
    func savesPreferences() async {
        let fixture = AppSettingsViewModelFixture()
        await fixture.start()
        fixture.viewModel.setLiveActivitiesEnabled(false)
        fixture.viewModel.setLiveActivityEnabled(false, id: "riding")
        fixture.viewModel.selectLiveActivityPresentation(id: "charging", presentationID: "summary")
        fixture.viewModel.setLiveActivityEnabled(false, id: "unknown")
        fixture.viewModel.selectLiveActivityPresentation(id: "riding", presentationID: "unknown")
        #expect(await waitUntil {
            await fixture.settingsRepository.load().liveActivities == .init(
                isEnabled: false, showsRiding: false, chargingDetailLevel: .summary
            )
        })
        fixture.viewModel.setLiveActivitiesEnabled(true)
        #expect(await waitUntil {
            await fixture.settingsRepository.load().liveActivities.isEnabled
        })
        #expect(fixture.viewModel.viewState.liveActivities.activities.first?.isEnabled == false)
        await fixture.viewModel.stopAndWait()
    }
}
