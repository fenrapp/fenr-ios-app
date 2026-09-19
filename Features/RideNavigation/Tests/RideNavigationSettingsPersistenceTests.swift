import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationSettingsPersistenceTests {
    @Test("Map source changes preserve Focus, camera and active navigation")
    func mapModeIsIndependentFromDisplayStyle() async throws {
        let fixture = RideNavigationViewModelFixture(
            settings: AppSettings(rideNavigation: .init(preferredMapStyle: .focus, showsRoadsInFocus: true))
        )
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        model.activityController.activity = .navigating
        model.screen = .map
        model.applyPreferredMapStyleForActiveNavigation()
        let viewport = try #require(NavigationMapViewport(
            center: NavigationMapCoordinate(latitudeDegrees: 41, longitudeDegrees: 2)!,
            visibleHeightMeters: 2_000, bearingDegrees: 45
        ))
        model.handleMapIntent(.rememberViewport(viewport))
        for id in ["map.offline", "map.normal"] {
            model.setMapStyle(id)
            #expect(await waitUntil { model.pendingSettings.isEmpty })
            #expect(model.viewState.mapScene.usesOfflineMap == (id == "map.offline"))
            #expect(model.viewState.mapMode.isEmphasized == (id == "map.offline"))
            #expect(model.viewState.mapScene.displayStyle == .focus)
            #expect(model.viewState.mapScene.showsRoadsInFocus)
            #expect(model.viewState.mapScene.camera == .viewport(viewport))
            #expect(model.viewState.activity == .navigating)
            #expect(model.makeMiniMapScene().usesOfflineMap == (id == "map.offline"))
            #expect(model.makeMiniMapScene().displayStyle == .focus)
        }
        model.setMapStyle("map.offline")
        model.setMapStyle(MapSourceDescriptor.appleHybrid.id)
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        #expect(model.viewState.mapScene.usesOfflineMap)
        #expect(model.viewState.mapScene.source == .appleHybrid)
        model.setMapStyle("map.normal")
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        #expect(model.viewState.mapScene.source == .appleHybrid)
        #expect(await fixture.settingsRepository.load().rideNavigation.mapMode == .normal)
        model.stop()
    }

    @Test("Rejected map mode persistence restores the previous provider")
    func rejectedMapModeRestoresProvider() async {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        model.setMapStyle("map.offline")
        #expect(await waitUntil { model.settingsSaveError != nil })
        #expect(!model.viewState.mapScene.usesOfflineMap)
        #expect(model.viewState.mapMode.selectedID == "map.normal")
        model.stop()
    }

    @Test("Rejected route preferences cancel stale calculations and recalculate confirmed preferences")
    func rejectedRoutePreferencesRecalculatePreview() async {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        let origin = GeographicCoordinate(latitudeDegrees: 41.0, longitudeDegrees: 2.0)!
        let destination = NavigationPlace(name: "Test destination", detail: "", coordinate: origin)
        model.locationSnapshot = .init(coordinate: origin)
        model.planningController.prepareExternalDestination(destination)
        model.screen = .map
        await fixture.settingsRepository.suspendNextSave()
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        model.setAvoidsTolls(true)
        await fixture.settingsRepository.waitUntilSaveIsSuspended()
        #expect(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        #expect(await fixture.roadRouteCalculator.lastPreferences?.avoidsTolls == true)
        await fixture.settingsRepository.resumeSuspendedSave()
        #expect(await waitUntil { await fixture.roadRouteCalculator.requestCount == 2 })
        #expect(!model.viewState.avoidsTolls)
        #expect(await fixture.roadRouteCalculator.lastPreferences?.avoidsTolls == false)
        let rejectedRoute = RoadNavigationRoute(
            name: "Rejected preference route", points: [origin], distanceMeters: 100,
            expectedTravelTime: 10, steps: []
        )
        let confirmedRoute = RoadNavigationRoute(
            name: "Confirmed preference route", points: [origin], distanceMeters: 200,
            expectedTravelTime: 20, steps: []
        )
        await fixture.roadRouteCalculator.succeed(request: 1, routes: [confirmedRoute])
        #expect(await waitUntil { model.planningController.snapshot.roadRoute?.name == confirmedRoute.name })
        await fixture.roadRouteCalculator.succeed(request: 0, routes: [rejectedRoute])
        #expect(await waitUntil { await fixture.roadRouteCalculator.completionCount == 2 })
        #expect(model.planningController.snapshot.roadRoute?.name == confirmedRoute.name)
        model.stop()
    }

    @Test("Failed map style persistence restores the confirmed active presentation")
    func failedMapStyleRestoresPresentation() async {
        let fixture = RideNavigationViewModelFixture(
            settings: AppSettings(rideNavigation: .init(preferredMapStyle: .standard))
        )
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        model.activityController.activity = .navigating
        model.screen = .map
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        model.setMapStyle("focus")
        #expect(await waitUntil { model.settingsSaveError != nil })
        #expect(model.appSettings.rideNavigation.preferredMapStyle == .standard)
        #expect(model.mapDisplayStyle == .map)
        #expect(model.mapSource == .appleStandard)
        model.stop()
    }

    @Test("Settings intents before a scoped snapshot do not change navigation presentation")
    func settingsIntentsRequireScopedSnapshot() {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.activityController.activity = .navigating
        model.setMapStyle("focus")
        #expect(model.settingsSaveError != nil)
        #expect(model.mapDisplayStyle == .map)
        model.setMiniMapScale(1.5)
        #expect(model.appSettings.rideNavigation.miniMapScale == .initial)
        #expect(model.pendingSettings.isEmpty)
    }

    @Test("Queued navigation settings preserve unrelated external changes")
    func navigationSettingsPreserveExternalChanges() async {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.settingsRepository.suspendNextSave()
        model.setMiniMapScale(1.5)
        await fixture.settingsRepository.waitUntilSaveIsSuspended()
        model.toggleMiniMapLayoutOrientation()
        var external = await fixture.settingsRepository.load()
        external.rideNavigation.showsCompassRing = true
        external.measurementSystem = .imperial
        await fixture.settingsRepository.publish(external)
        #expect(await waitUntil { model.appSettings.measurementSystem == .imperial })
        #expect(model.appSettings.rideNavigation.miniMapScale.value == 1.5)
        await fixture.settingsRepository.resumeSuspendedSave()
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        let stored = await fixture.settingsRepository.load()
        #expect(stored.rideNavigation.showsCompassRing)
        #expect(stored.rideNavigation.miniMapScale.value == 1.5)
        #expect(stored.rideNavigation.miniMapLayoutOrientation == .landscape)
        model.stop()
    }

    @Test("A failed navigation setting rolls back without blocking the next intent")
    func failedNavigationSettingRollsBack() async {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.settingsRepository.failNextUpdate(.persistenceFailed)
        model.setMiniMapScale(1.5)
        model.toggleMiniMapLayoutOrientation()
        #expect(await waitUntil { model.pendingSettings.isEmpty && model.settingsSaveError != nil })
        #expect(model.appSettings.rideNavigation.miniMapScale == .initial)
        #expect(model.appSettings.rideNavigation.miniMapLayoutOrientation == .landscape)
        model.stop()
    }

    @Test("Stopped settings workers cannot replace a restarted worker or write queued old intents")
    func stoppedSettingsWorkerCannotReplaceRestartedWorker() async {
        let fixture = RideNavigationViewModelFixture()
        let model = fixture.viewModel
        model.start()
        #expect(await waitUntil { model.pendingSettings.confirmed != nil })
        await fixture.settingsRepository.suspendNextSave()
        model.setMiniMapScale(1.5)
        await fixture.settingsRepository.waitUntilSaveIsSuspended()
        model.toggleMiniMapLayoutOrientation()
        model.stop()
        model.start()
        model.setMiniMapScale(0.5)
        await fixture.settingsRepository.resumeSuspendedSave()
        #expect(await waitUntil { model.pendingSettings.isEmpty })
        #expect(await fixture.settingsRepository.load().rideNavigation.miniMapScale == MiniMapScale(0.5))
        #expect(await fixture.settingsRepository.load().rideNavigation.miniMapLayoutOrientation == .portrait)
        model.stop()
    }

}
