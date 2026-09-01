import Foundation
@testable import RideNavigationDomain
import Testing

struct RideRouteGuidancePlanTests {
    @Test("entry match distinguishes forward, reverse, and unreliable course")
    func entryDirectionClassification() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41)
        let end = RideRouteGuidanceTestFactory.coordinate(latitude: 41.002)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [[start, end]])
        )
        let midpoint = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001)

        let forward = try #require(
            plan.entryMatch(for: RideRouteGuidanceTestFactory.sample(midpoint, courseDegrees: 0))
        )
        let reverse = try #require(
            plan.entryMatch(for: RideRouteGuidanceTestFactory.sample(midpoint, courseDegrees: 180))
        )
        let ambiguous = try #require(
            plan.entryMatch(
                for: RideRouteGuidanceTestFactory.sample(
                    midpoint,
                    courseDegrees: nil,
                    courseAccuracyDegrees: nil
                )
            )
        )

        #expect(forward.classification == .forward)
        #expect(forward.selectedProjection != nil)
        #expect(reverse.classification == .reverse)
        #expect(reverse.selectedProjection != nil)
        #expect(ambiguous.classification == .ambiguous)
        #expect(ambiguous.selectedProjection == nil)
    }

    @Test("overlapping outbound and return edges expose both ordered occurrences")
    func outAndBackExposesOccurrences() async throws {
        let south = RideRouteGuidanceTestFactory.coordinate(latitude: 41)
        let north = RideRouteGuidanceTestFactory.coordinate(latitude: 41.002)
        let route = RideRouteGuidanceTestFactory.route(segments: [[south, north, south]])
        let plan = try await RideRouteGuidanceTestFactory.plan(for: route)
        let midpoint = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001)

        let northbound = try #require(
            plan.entryMatch(for: RideRouteGuidanceTestFactory.sample(midpoint, courseDegrees: 0))
        )
        #expect(northbound.classification == .ambiguous)
        #expect(northbound.projections.count == 2)
        #expect(northbound.projections[0].position.distanceAlongRouteMeters < route.distanceMeters / 2)
        #expect(northbound.projections[1].position.distanceAlongRouteMeters > route.distanceMeters / 2)
    }

    @Test("slices never bridge distinct GPX segments")
    func slicesPreserveSegmentGaps() async throws {
        let first = [
            RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2),
            RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2)
        ]
        let second = [
            RideRouteGuidanceTestFactory.coordinate(latitude: 42, longitude: 3),
            RideRouteGuidanceTestFactory.coordinate(latitude: 42.001, longitude: 3)
        ]
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [first, second])
        )

        let slices = plan.slices(
            in: RideRouteDistanceRange(
                lowerBoundMeters: .zero,
                upperBoundMeters: plan.totalDistanceMeters
            )
        )

        #expect(slices.count == 2)
        #expect(slices.map(\.segmentIndex) == [0, 1])
        #expect(slices.allSatisfy { $0.coordinates.count == 2 })
        #expect(plan.totalDistanceMeters < 250)
    }

    @Test("dense sampling does not create false forks and real turns keep their cue")
    func denseSamplingAndTurnCue() async throws {
        let denseStraight = (0...20).map { index in
            RideRouteGuidanceTestFactory.coordinate(
                latitude: 41 + Double(index) * 0.000_05
            )
        }
        let straightPlan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [denseStraight])
        )
        #expect(straightPlan.nextDecision(after: .zero) == nil)

        let turnPlan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(
                segments: [[
                    RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2),
                    RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2),
                    RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.001)
                ]]
            )
        )
        let decision = try #require(turnPlan.nextDecision(after: .zero))
        #expect(decision.direction == .right)
        #expect(!decision.isFork)
    }

    @Test("a fork can intersect the middle of a nonadjacent edge")
    func midpointIntersectionIsFork() async throws {
        let south = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2)
        let north = RideRouteGuidanceTestFactory.coordinate(latitude: 41.002, longitude: 2)
        let west = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 1.999)
        let east = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.001)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(
                segments: [[south, north], [west, east]]
            )
        )

        let decision = try #require(plan.nextDecision(after: .zero))

        #expect(decision.direction == .straight)
        #expect(decision.isFork)
        #expect(abs(decision.coordinate.latitudeDegrees - 41.001) < 0.0002)
    }

    @Test("plan preparation cooperatively stops when its owner cancels")
    func planPreparationChecksCancellation() {
        let points = (0..<5_000).map { index in
            RideRouteGuidanceTestFactory.coordinate(
                latitude: 41 + Double(index) * 0.000_001
            )
        }
        var cancellationChecks = 0

        let plan = RideRouteGuidancePlan(
            route: RideRouteGuidanceTestFactory.route(segments: [points]),
            direction: .forward,
            configuration: .standard,
            shouldCancel: {
                cancellationChecks += 1
                return cancellationChecks > 1
            }
        )

        #expect(plan == nil)
        #expect(cancellationChecks == 2)
    }

    @Test("a 100k point plan remains indexed and corridor work stays bounded")
    func largeRouteFeasibility() async throws {
        let points = (0..<100_000).map { index in
            RideRouteGuidanceTestFactory.coordinate(
                latitude: 41 + Double(index) * 0.000_001
            )
        }
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [points])
        )
        let midpoint = points[50_000]
        let match = try #require(
            plan.entryMatch(for: RideRouteGuidanceTestFactory.sample(midpoint))
        )
        let projection = try #require(match.selectedProjection)
        let corridor = RideRouteDistanceRange(
            lowerBoundMeters: projection.position.distanceAlongRouteMeters,
            upperBoundMeters: projection.position.distanceAlongRouteMeters + 250
        )

        #expect(plan.totalDistanceMeters > 10_000)
        #expect(plan.slices(in: corridor).flatMap(\.coordinates).count < 250)
        #expect(match.projections.count < 200)
    }
}
