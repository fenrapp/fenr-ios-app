import Observation
@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationObservationTests {
    @Test("Computed transfer requests track library creation and dismissal", arguments: [false, true])
    func observesLibraryTransferRequests(isShare: Bool) async throws {
        let route = LibraryControllerTestRoutes.route(name: "Observation route")
        let fixture = RideNavigationViewModelFixture(routes: [route])
        let model = fixture.viewModel
        defer { model.stop() }
        model.start()
        try #require(await waitUntil { model.viewState.savedRoutes.contains { $0.id == route.id } })
        model.openSavedRoute(id: route.id)
        let created = NavigationObservationRecorder()
        withObservationTracking {
            if isShare {
                _ = model.shareRequest
            } else {
                _ = model.exportRequest
            }
        } onChange: {
            created.record()
        }
        if isShare {
            model.shareSavedRoute(id: route.id)
        } else {
            model.exportCompletedRoute()
        }
        let request = try #require(isShare ? model.shareRequest : model.exportRequest)
        #expect(request.filename == "Observation-route.gpx")
        #expect(!request.data.isEmpty)
        #expect(created.count == 1)

        let cleared = NavigationObservationRecorder()
        withObservationTracking {
            if isShare {
                _ = model.shareRequest
            } else {
                _ = model.exportRequest
            }
        } onChange: {
            cleared.record()
        }
        if isShare {
            model.clearShareRequest()
        } else {
            model.clearExportRequest()
        }
        #expect((isShare ? model.shareRequest : model.exportRequest) == nil)
        #expect(cleared.count == 1)
    }

    @Test("Mini controls invalidate their own presentation while the full-screen presentation stays frozen")
    func observesMiniPresentationIndependently() async throws {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        defer { model.stop() }
        model.start()
        try #require(await waitUntil { model.pendingSettings.confirmed != nil })
        model.setPresentationMode(.mini)
        let fullScreen = model.viewState
        let recorder = NavigationObservationRecorder()
        withObservationTracking {
            _ = model.miniViewState.scale
        } onChange: {
            recorder.record()
        }
        model.setMiniMapScale(1.5)
        #expect(model.miniViewState.scale == 1.5)
        #expect(recorder.count == 1)
        #expect(model.viewState == fullScreen)
        try #require(await waitUntil { model.pendingSettings.isEmpty })
    }

    @Test("Settings save failures and dismissal independently invalidate the alert presentation")
    func observesSettingsFailureAndDismissal() async throws {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        defer { model.stop() }
        model.start()
        try #require(await waitUntil { model.pendingSettings.confirmed != nil })
        let initialScale = model.miniViewState.scale
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        let failed = NavigationObservationRecorder()
        withObservationTracking {
            _ = model.settingsSaveError
        } onChange: {
            failed.record()
        }
        model.setMiniMapScale(1.5)
        try #require(await waitUntil { model.pendingSettings.isEmpty && model.settingsSaveError != nil })
        #expect(failed.count == 1)
        #expect(model.miniViewState.scale == initialScale)

        let dismissed = NavigationObservationRecorder()
        withObservationTracking {
            _ = model.settingsSaveError
        } onChange: {
            dismissed.record()
        }
        model.dismissSettingsSaveError()
        #expect(model.settingsSaveError == nil)
        #expect(dismissed.count == 1)
    }
}
