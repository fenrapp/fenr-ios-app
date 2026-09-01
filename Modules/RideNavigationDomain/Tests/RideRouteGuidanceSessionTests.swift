import Foundation
@testable import RideNavigationDomain
import Testing

struct RideRouteGuidanceSessionTests {
    @Test("a circular route does not arrive at its coincident start")
    func circularArrivalUsesOrderedFinish() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2)
        let northWest = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2)
        let northEast = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.001)
        let southEast = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2.001)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(
                segments: [[start, northWest, northEast, southEast, start]]
            )
        )
        var session = RideRouteGuidanceSession(plan: plan)

        let initialResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(start, seconds: 0, courseDegrees: 0)
        )
        let initial = try #require(initialResult)
        #expect(!initial.hasReachedFinish)
        #expect(initial.projection.position.distanceAlongRouteMeters < 1)

        _ = session.update(
            with: RideRouteGuidanceTestFactory.sample(northWest, seconds: 10, courseDegrees: 90)
        )
        _ = session.update(
            with: RideRouteGuidanceTestFactory.sample(northEast, seconds: 20, courseDegrees: 180)
        )
        _ = session.update(
            with: RideRouteGuidanceTestFactory.sample(southEast, seconds: 30, courseDegrees: 270)
        )
        let finishedResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(start, seconds: 40, courseDegrees: 270)
        )
        let finished = try #require(finishedResult)

        #expect(finished.hasReachedFinish)
        #expect(plan.totalDistanceMeters - finished.projection.position.distanceAlongRouteMeters < 1)
    }

    @Test("an out-and-back session remains on its selected occurrence")
    func outAndBackMaintainsOccurrence() async throws {
        let south = RideRouteGuidanceTestFactory.coordinate(latitude: 41)
        let north = RideRouteGuidanceTestFactory.coordinate(latitude: 41.002)
        let midpoint = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001)
        let route = RideRouteGuidanceTestFactory.route(segments: [[south, north, south]])
        let plan = try await RideRouteGuidanceTestFactory.plan(for: route)
        let match = try #require(
            plan.entryMatch(for: RideRouteGuidanceTestFactory.sample(midpoint, courseDegrees: 0))
        )
        let outbound = try #require(
            match.projections.first { $0.localBearingDegrees < 1 || $0.localBearingDegrees > 359 }
        )
        var session = RideRouteGuidanceSession(plan: plan, startingAt: outbound)

        let snapshotResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(latitude: 41.0011),
                seconds: 1,
                courseDegrees: 0
            )
        )
        let snapshot = try #require(snapshotResult)

        #expect(snapshot.projection.position.distanceAlongRouteMeters < route.distanceMeters / 2)
        #expect(snapshot.directionalIndicators.first.map {
            $0.bearingDegrees < 1 || $0.bearingDegrees > 359
        } == true)
        #expect(snapshot.directionalIndicators.contains {
            $0.bearingDegrees > 179 && $0.bearingDegrees < 181
        })
    }

    @Test("figure-eight crossings retain the selected later occurrence")
    func figureEightUsesContinuity() async throws {
        let crossing = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2)
        let points = [
            RideRouteGuidanceTestFactory.coordinate(latitude: 40.999, longitude: 1.999),
            crossing,
            RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.001),
            RideRouteGuidanceTestFactory.coordinate(latitude: 40.999, longitude: 2.001),
            crossing,
            RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 1.999)
        ]
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [points])
        )
        let match = try #require(
            plan.entryMatch(
                for: RideRouteGuidanceTestFactory.sample(
                    crossing,
                    courseDegrees: nil,
                    courseAccuracyDegrees: nil
                )
            )
        )
        let later = try #require(match.projections.last)
        var session = RideRouteGuidanceSession(plan: plan, startingAt: later)

        let snapshotResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(
                crossing,
                seconds: 1,
                courseDegrees: nil,
                courseAccuracyDegrees: nil
            )
        )
        let snapshot = try #require(snapshotResult)

        #expect(snapshot.projection.position.distanceAlongRouteMeters > plan.totalDistanceMeters * 0.6)
    }

    @Test("poor GPS accuracy does not mutate progress or trigger arrival")
    func inaccurateSampleKeepsReliableProjection() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41)
        let end = RideRouteGuidanceTestFactory.coordinate(latitude: 41.003)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [[start, end]])
        )
        var session = RideRouteGuidanceSession(plan: plan)
        let initialResult = session.update(with: RideRouteGuidanceTestFactory.sample(start))
        let initial = try #require(initialResult)

        let inaccurateResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(
                end,
                seconds: 20,
                horizontalAccuracyMeters: 60
            )
        )
        let inaccurate = try #require(inaccurateResult)

        #expect(inaccurate.projection == initial.projection)
        #expect(!inaccurate.hasReachedFinish)
    }

    @Test("a future occurrence at a known fork becomes wrong fork without rebasing")
    func wrongForkDoesNotRebase() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2)
        let fork = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2)
        let north = RideRouteGuidanceTestFactory.coordinate(latitude: 41.003, longitude: 2)
        let east = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.003)
        let configuration = RideRouteGuidanceConfiguration(continuityLookAheadMeters: 100)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(
                segments: [[start, fork, north, fork, east]]
            ),
            configuration: configuration
        )
        let entry = try #require(
            plan.entryMatch(
                for: RideRouteGuidanceTestFactory.sample(
                    RideRouteGuidanceTestFactory.coordinate(latitude: 41.0008, longitude: 2),
                    courseDegrees: 0
                )
            )?.selectedProjection
        )
        var session = RideRouteGuidanceSession(
            plan: plan,
            startingAt: entry,
            configuration: configuration
        )
        #expect(plan.nextDecision(
            after: entry.position.distanceAlongRouteMeters
        )?.isFork == true)
        let samples = [
            RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.0008),
                seconds: 1,
                courseDegrees: 90
            ),
            RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.0011),
                seconds: 3,
                courseDegrees: 90
            ),
            RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.0015),
                seconds: 6,
                courseDegrees: 90
            ),
            RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(latitude: 41.001, longitude: 2.0025),
                seconds: 15,
                courseDegrees: 90
            )
        ]
        var snapshot: RideRouteGuidanceSnapshot?
        for sample in samples {
            snapshot = session.update(with: sample)
        }

        let result = try #require(snapshot)
        #expect(result.routeState == .wrongFork)
        #expect(result.projection.position.distanceAlongRouteMeters < plan.totalDistanceMeters / 2)
    }

}
