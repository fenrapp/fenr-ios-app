@testable import RideNavigationDomain
import Testing

struct RideRouteGuidanceSessionRecoveryTests {
    @Test("returning to the expected corridor emits a rejoined transition")
    func expectedCorridorRecoveryIsRejoined() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2)
        let midpoint = RideRouteGuidanceTestFactory.coordinate(latitude: 41.0002, longitude: 2)
        let finish = RideRouteGuidanceTestFactory.coordinate(latitude: 41.003, longitude: 2)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [[start, finish]])
        )
        var session = RideRouteGuidanceSession(plan: plan)

        _ = session.update(with: RideRouteGuidanceTestFactory.sample(start))
        let offRoute = RideRouteGuidanceTestFactory.coordinate(latitude: 41.0002, longitude: 2.001)
        let offResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(offRoute, seconds: 5)
        )
        let offSnapshot = try #require(offResult)
        let recoveredResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(midpoint, seconds: 10)
        )
        let recovered = try #require(recoveredResult)

        #expect(offSnapshot.routeState == .offRoute)
        #expect(recovered.routeState == .rejoined)
    }

    @Test("recovery waits until the rider is within the recovery corridor")
    func recoveryUsesNarrowerThreshold() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2)
        let finish = RideRouteGuidanceTestFactory.coordinate(latitude: 41.003, longitude: 2)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [[start, finish]])
        )
        var session = RideRouteGuidanceSession(plan: plan)
        _ = session.update(with: RideRouteGuidanceTestFactory.sample(start))
        let far = RideRouteGuidanceTestFactory.coordinate(latitude: 41.0002, longitude: 2.001)
        _ = session.update(with: RideRouteGuidanceTestFactory.sample(far, seconds: 5))
        let fortyMetersAway = RideRouteGuidanceTestFactory.coordinate(
            latitude: 41.0002,
            longitude: 2.00048
        )

        let result = session.update(
            with: RideRouteGuidanceTestFactory.sample(fortyMetersAway, seconds: 10)
        )
        let snapshot = try #require(result)

        #expect(snapshot.routeState == .offRoute)
    }

    @Test("published progress remains monotonic through bounded GPS backtracking")
    func completedProgressDoesNotRegress() async throws {
        let start = RideRouteGuidanceTestFactory.coordinate(latitude: 41)
        let advanced = RideRouteGuidanceTestFactory.coordinate(latitude: 41.001)
        let backtracked = RideRouteGuidanceTestFactory.coordinate(latitude: 41.0008)
        let finish = RideRouteGuidanceTestFactory.coordinate(latitude: 41.003)
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [[start, finish]])
        )
        var session = RideRouteGuidanceSession(plan: plan)

        _ = session.update(with: RideRouteGuidanceTestFactory.sample(start))
        let forwardResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(advanced, seconds: 10)
        )
        let forward = try #require(forwardResult)
        let backwardResult = session.update(
            with: RideRouteGuidanceTestFactory.sample(backtracked, seconds: 12)
        )
        let backward = try #require(backwardResult)

        #expect(
            backward.completedRange.upperBoundMeters
                == forward.completedRange.upperBoundMeters
        )
    }

    @Test("a stable alternate occurrence can be adopted outside a fork")
    func stableAlternateRejoins() async throws {
        var session = try await makeRejoinSession()
        var snapshot: RideRouteGuidanceSnapshot?
        for sample in alternateSamples(courseDegrees: 0) {
            snapshot = session.update(with: sample)
        }

        let result = try #require(snapshot)
        #expect(result.routeState == .rejoined)
        #expect(result.projection.position.segmentIndex == 1)
    }

    @Test("an alternate occurrence with incompatible course cannot rebase")
    func incompatibleCourseDoesNotRejoin() async throws {
        var session = try await makeRejoinSession()
        var snapshot: RideRouteGuidanceSnapshot?
        for sample in alternateSamples(courseDegrees: 180) {
            snapshot = session.update(with: sample)
        }

        let result = try #require(snapshot)
        #expect(result.routeState == .offRoute)
        #expect(result.projection.position.segmentIndex == 0)
    }

    private func makeRejoinSession() async throws -> RideRouteGuidanceSession {
        let main = [
            RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2),
            RideRouteGuidanceTestFactory.coordinate(latitude: 41.003, longitude: 2)
        ]
        let skipped = [
            RideRouteGuidanceTestFactory.coordinate(latitude: 41, longitude: 2.003),
            RideRouteGuidanceTestFactory.coordinate(latitude: 41.003, longitude: 2.003)
        ]
        let configuration = RideRouteGuidanceConfiguration(
            continuityLookAheadMeters: 80,
            wrongForkConfirmationSeconds: 2,
            wrongForkConfirmationDistanceMeters: 10,
            rejoinConfirmationSeconds: 5,
            rejoinConfirmationDistanceMeters: 100
        )
        let plan = try await RideRouteGuidanceTestFactory.plan(
            for: RideRouteGuidanceTestFactory.route(segments: [main, skipped]),
            configuration: configuration
        )
        let entry = try #require(plan.entryMatch(
            for: RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(latitude: 41.0005, longitude: 2)
            )
        )?.selectedProjection)
        return RideRouteGuidanceSession(
            plan: plan,
            startingAt: entry,
            configuration: configuration
        )
    }

    private func alternateSamples(courseDegrees: Double) -> [RideRouteGuidanceSample] {
        [1.0, 3.0, 7.0].enumerated().map { index, seconds in
            RideRouteGuidanceTestFactory.sample(
                RideRouteGuidanceTestFactory.coordinate(
                    latitude: 41.001 + Double(index) * 0.00015,
                    longitude: 2.003
                ),
                seconds: seconds,
                courseDegrees: courseDegrees
            )
        }
    }
}
