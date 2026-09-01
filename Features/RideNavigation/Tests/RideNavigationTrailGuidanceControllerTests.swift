import EnvironmentDomain
import Foundation
@testable import RideNavigation
import RideNavigationDomain
import Testing

@MainActor
struct RideNavigationTrailGuidanceControllerTests {
    @Test("preparation cancellation and acceptance preserve deferred start")
    func preparationLifecyclePreservesDeferredStart() async throws {
        let route = makeRoute()
        let controller = makeController()

        controller.beginPreparation(
            routeID: route.id,
            direction: .forward,
            startAfterPreparation: false
        )
        #expect(controller.snapshot.routeID == route.id)
        #expect(controller.snapshot.direction == .forward)
        #expect(controller.snapshot.isPreparing)
        #expect(controller.snapshot.plan == nil)

        controller.requestStartAfterPreparation()
        controller.cancelPreparation()
        #expect(!controller.snapshot.isPreparing)

        controller.beginPreparation(
            routeID: route.id,
            direction: .reverse,
            startAfterPreparation: true
        )
        let plannedRoute = await controller.makePlan(for: route, direction: .reverse)
        let plan = try #require(plannedRoute)

        #expect(controller.acceptPreparedPlan(plan))
        #expect(!controller.snapshot.isPreparing)
        #expect(controller.snapshot.direction == .reverse)
        #expect(controller.snapshot.plan != nil)
    }

    @Test("an active session publishes its latest guidance snapshot")
    func activeSessionPublishesGuidance() async throws {
        let route = makeRoute()
        let controller = makeController()
        try await prepareAndStart(controller, route: route)

        #expect(controller.snapshot.hasActiveSession)
        #expect(controller.snapshot.guidance == nil)

        let published = controller.update(with: sample(latitude: 41, seconds: 0))
        let guidance = try #require(published)

        #expect(controller.snapshot.guidance == guidance)
        #expect(controller.snapshot.hasActiveSession)
    }

    @Test("entry and arrival prompts can be dismissed or suppressed")
    func promptsAndArrivalSuppressionAreExplicit() async throws {
        let route = makeRoute()
        let controller = makeController()
        let entryPrompt = RideNavigationTrailEntryPrompt(
            title: "Choose direction",
            detail: "Select how to follow this trail.",
            availableDirections: [.forward, .reverse]
        )

        controller.presentEntryPrompt(entryPrompt)
        #expect(controller.snapshot.entryPrompt == entryPrompt)
        controller.dismissEntryPrompt()
        #expect(controller.snapshot.entryPrompt == nil)

        try await prepareAndStart(controller, route: route)
        _ = controller.update(with: sample(latitude: 41, seconds: 0))
        let finished = try #require(
            controller.update(with: sample(latitude: 41.001, seconds: 10))
        )
        #expect(finished.hasReachedFinish)
        #expect(controller.presentArrivalIfNeeded(for: finished))
        #expect(controller.snapshot.arrivalPrompt != nil)
        #expect(!controller.presentArrivalIfNeeded(for: finished))

        #expect(controller.keepRidingAfterArrival())
        #expect(controller.snapshot.arrivalPrompt == nil)
        #expect(!controller.presentArrivalIfNeeded(for: finished))
    }

    @Test("route state and turn announcements are deduplicated")
    func announcementsAreDeduplicated() {
        let controller = makeController()
        let decision = RideRouteGuidanceDecision(
            direction: .left,
            coordinate: coordinate(latitude: 41.0005),
            distanceMeters: 20,
            isFork: true,
            identifier: "decision-1"
        )

        #expect(matches(controller.routeStateAction(for: .offRoute), .announceOffRoute))
        #expect(matches(controller.routeStateAction(for: .offRoute), .none))
        #expect(matches(controller.routeStateAction(for: .wrongFork), .announceWrongFork))
        #expect(matches(controller.routeStateAction(for: .wrongFork), .none))
        #expect(matches(controller.routeStateAction(for: .rejoined), .announceRejoined))
        #expect(matches(controller.routeStateAction(for: .rejoined), .none))
        #expect(controller.shouldAnnounceDecision(decision))
        #expect(!controller.shouldAnnounceDecision(decision))
    }

    @Test("reset clears the complete guidance snapshot")
    func resetClearsSnapshot() async throws {
        let route = makeRoute()
        let controller = makeController()
        try await prepareAndStart(controller, route: route)
        _ = controller.update(with: sample(latitude: 41, seconds: 0))
        controller.presentEntryPrompt(
            RideNavigationTrailEntryPrompt(
                title: "Choose direction",
                detail: "Select how to follow this trail.",
                availableDirections: [.forward]
            )
        )

        controller.reset()

        let snapshot = controller.snapshot
        #expect(snapshot.routeID == nil)
        #expect(snapshot.direction == nil)
        #expect(snapshot.plan == nil)
        #expect(snapshot.guidance == nil)
        #expect(snapshot.entryPrompt == nil)
        #expect(snapshot.arrivalPrompt == nil)
        #expect(!snapshot.isPreparing)
        #expect(!snapshot.hasActiveSession)
    }

    private func makeController() -> RideNavigationTrailGuidanceController {
        RideNavigationTrailGuidanceController(
            planner: DefaultRideRouteGuidancePlanner(),
            configuration: RideRouteGuidanceConfiguration(
                arrivalDistanceMeters: 30,
                minimumArrivalAdvanceMeters: 10
            )
        )
    }

    private func prepareAndStart(
        _ controller: RideNavigationTrailGuidanceController,
        route: RideRoute
    ) async throws {
        controller.beginPreparation(
            routeID: route.id,
            direction: .forward,
            startAfterPreparation: false
        )
        let plannedRoute = await controller.makePlan(for: route, direction: .forward)
        let plan = try #require(plannedRoute)
        #expect(!controller.acceptPreparedPlan(plan))
        controller.startSession(at: nil)
    }

    private func makeRoute() -> RideRoute {
        let date = Date(timeIntervalSince1970: Constants.referenceTime)
        return RideRoute(
            name: "Controller trail",
            createdAt: date,
            segments: [
                RideRouteSegment(points: [
                    RideRoutePoint(coordinate: coordinate(latitude: 41), timestamp: date),
                    RideRoutePoint(
                        coordinate: coordinate(latitude: 41.001),
                        timestamp: date.addingTimeInterval(60)
                    )
                ])
            ]
        )
    }

    private func sample(
        latitude: Double,
        seconds: TimeInterval
    ) -> RideRouteGuidanceSample {
        RideRouteGuidanceSample(
            coordinate: coordinate(latitude: latitude),
            horizontalAccuracyMeters: 5,
            courseDegrees: 0,
            courseAccuracyDegrees: 5,
            speedKilometersPerHour: 40,
            observedAt: Date(timeIntervalSince1970: Constants.referenceTime + seconds)
        )
    }

    private func coordinate(latitude: Double) -> GeographicCoordinate {
        GeographicCoordinate(latitudeDegrees: latitude, longitudeDegrees: 2)!
    }

    private func matches(
        _ lhs: RideNavigationTrailGuidanceController.RouteStateAction,
        _ rhs: RideNavigationTrailGuidanceController.RouteStateAction
    ) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none),
             (.announceOffRoute, .announceOffRoute),
             (.announceWrongFork, .announceWrongFork),
             (.announceRejoined, .announceRejoined):
            true
        default:
            false
        }
    }

    private enum Constants {
        static let referenceTime: TimeInterval = 1_700_000_000
    }
}
