@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationActivityMiniArrivalTests {
    @Test("An automatic road arrival keeps the final mini map frozen until expansion")
    func roadArrivalFreezesMiniCompletion() async throws {
        let timing = ControllableRideNavigationTiming()
        let fixture = RideNavigationViewModelFixture(timing: timing.makeTiming())
        let model = fixture.viewModel
        model.start()
        defer { model.stop() }
        try #require(await waitUntil { await fixture.deviceSpeedRepository.activeObserverCount() == 1 })
        await fixture.deviceSpeedRepository.send(ActivityControllerTestData.sample(index: 0, seconds: 0))
        try #require(await waitUntil { model.viewState.mapScene.userCoordinate != nil })
        model.calculateRoadPreview(
            from: ActivityControllerTestData.coordinate(index: 0),
            to: ActivityControllerTestData.destination(), showsSearchLoading: false
        )
        try #require(await waitUntil { await fixture.roadRouteCalculator.requestCount == 1 })
        await fixture.roadRouteCalculator.succeed(routes: [ActivityControllerTestData.roadRoute()])
        try #require(await waitUntil { model.viewState.screen == .map && model.viewState.activity == .preview })
        model.startPreviewedRoute()
        model.setPresentationMode(.mini)
        try #require(await waitUntil { await fixture.deviceSpeedRepository.activeObserverCount() == 1 })
        await fixture.deviceSpeedRepository.send(ActivityControllerTestData.sample(index: 5, seconds: 30))
        try #require(await waitUntil {
            model.screen == .summary && model.miniViewState.statusText != nil
        })
        try #require(await waitUntil { await fixture.deviceSpeedRepository.activeObserverCount() == 0 })
        let finalMap = model.miniViewState.mapScene
        let mapMapper = model.dependencies.mapPresentationMapper
        #expect(finalMap.userCoordinate == mapMapper.coordinate(ActivityControllerTestData.coordinate(index: 5)))
        let roadCoordinates = mapMapper.coordinates(ActivityControllerTestData.roadRoute().points)
        #expect(finalMap.polylines.contains { $0.role == .approach && $0.points == roadCoordinates })
        await fixture.deviceSpeedRepository.sendToCurrentObservers(
            ActivityControllerTestData.sample(index: 9, seconds: 40)
        )
        #expect(model.miniViewState.mapScene == finalMap)
        model.setPresentationMode(.fullScreen)
        #expect(model.viewState.screen == .summary)
        #expect(model.viewState.summaryTitle == "Destination reached")
        #expect(model.miniViewState.statusText == nil)
    }
}
