@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationActivityTransitionTests {
    @Test("Arriving at a road approach resumes the selected trail without ending its activity or trace")
    func roadApproachContinuesIntoTrail() async throws {
        let timing = ControllableRideNavigationTiming()
        let fixture = ActivityControllerTestFixture.make(timing: timing.makeTiming())
        let trail = ActivityControllerTestData.trailRoute(name: "Selected trail", finishIndex: 9)
        fixture.start()
        defer { fixture.stop() }
        fixture.planning.selectTrailRoute(trail)
        fixture.activity.prepareTrailPreview()
        await fixture.activity.trailPreparationTask?.value
        fixture.receive(index: -3, seconds: 0)
        fixture.planning.approach(
            from: ActivityControllerTestData.coordinate(index: -3),
            to: ActivityControllerTestData.approachDestination(), preferences: .init()
        )
        let approach = fixture.planning.routeTask
        try #require(await waitUntil { await fixture.roadCalculator.requestCount == 1 })
        await fixture.roadCalculator.succeed(routes: [ActivityControllerTestData.approachRoute()])
        await approach?.value
        _ = fixture.activity.beginRoadNavigation(isApproach: true)
        #expect(fixture.activity.snapshot.activity == .navigating)
        #expect(fixture.planning.snapshot.roadNavigationPurpose == .trailApproach)
        fixture.receive(index: 0, seconds: 20)
        #expect(fixture.activity.snapshot.activity == .following)
        #expect(fixture.planning.snapshot.selectedRoute?.id == trail.id)
        #expect(fixture.planning.snapshot.roadRoute == nil)
        #expect(fixture.planning.snapshot.roadNavigationPurpose == nil)
        #expect(fixture.activity.snapshot.completion == nil)
        #expect(fixture.activity.snapshot.completedRecording == nil)
        #expect(fixture.activity.snapshot.breadcrumb.route?.points.map(\.coordinate) == [
            ActivityControllerTestData.coordinate(index: -3), ActivityControllerTestData.coordinate(index: 0)
        ])
        #expect(fixture.activity.clockTask != nil)
    }
}
