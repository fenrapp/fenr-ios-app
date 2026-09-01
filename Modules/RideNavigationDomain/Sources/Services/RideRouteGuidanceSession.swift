import EnvironmentDomain
import Foundation

public struct RideRouteGuidanceSession: Sendable {
    private let plan: RideRouteGuidancePlan
    private let configuration: RideRouteGuidanceConfiguration
    private var activeProjection: RideRouteProjection?
    private var startingDistanceMeters: Double?
    private var maximumDistanceAlongRouteMeters: Double
    private var routeState: RideRouteGuidanceRouteState = .onRoute
    private var alternativeCandidate: AlternativeCandidate?
    private var lastReliableObservedAt: Date?
    private var protectedForkRange: ClosedRange<Double>?

    public init(
        plan: RideRouteGuidancePlan,
        startingAt projection: RideRouteProjection? = nil,
        configuration: RideRouteGuidanceConfiguration = .standard
    ) {
        self.plan = plan
        self.configuration = configuration
        activeProjection = projection
        startingDistanceMeters = projection?.position.distanceAlongRouteMeters
        maximumDistanceAlongRouteMeters = projection?.position.distanceAlongRouteMeters ?? .zero
    }

    public mutating func update(
        with sample: RideRouteGuidanceSample
    ) -> RideRouteGuidanceSnapshot? {
        guard plan.hasReliableTrackingAccuracy(sample) else {
            guard let activeProjection else { return nil }
            return snapshot(
                projection: activeProjection,
                state: routeState,
                hasReachedFinish: false
            )
        }
        let searchDistance = max(
            configuration.offRouteDistanceMeters * 3,
            configuration.entryDistanceMeters
        )
        let nearby = plan.projections(
            near: sample.coordinate,
            maximumDistanceMeters: searchDistance
        )
        guard !nearby.isEmpty else {
            guard let activeProjection else { return nil }
            routeState = .offRoute
            alternativeCandidate = nil
            return snapshot(
                projection: activeProjection,
                state: .offRoute,
                hasReachedFinish: false
            )
        }
        guard let previous = activeProjection else {
            let selected = initialProjection(from: nearby, sample: sample)
            lastReliableObservedAt = sample.observedAt
            activeProjection = selected
            startingDistanceMeters = selected.position.distanceAlongRouteMeters
            maximumDistanceAlongRouteMeters = selected.position.distanceAlongRouteMeters
            routeState = selected.distanceFromRouteMeters <= configuration.offRouteDistanceMeters
                ? .onRoute
                : .offRoute
            return snapshot(
                projection: selected,
                state: routeState,
                hasReachedFinish: false
            )
        }
        let elapsedSeconds = lastReliableObservedAt.map {
            max(sample.observedAt.timeIntervalSince($0), .zero)
        } ?? .zero
        lastReliableObservedAt = sample.observedAt
        return updateEstablishedSession(
            with: sample,
            nearby: nearby,
            previous: previous,
            elapsedSeconds: elapsedSeconds
        )
    }

    private mutating func updateEstablishedSession(
        with sample: RideRouteGuidanceSample,
        nearby: [RideRouteProjection],
        previous: RideRouteProjection,
        elapsedSeconds: TimeInterval
    ) -> RideRouteGuidanceSnapshot {
        let previousDistance = previous.position.distanceAlongRouteMeters
        updateProtectedForkRange(after: previousDistance)
        let expected = expectedProjection(
            from: nearby,
            previous: previous,
            sample: sample,
            elapsedSeconds: elapsedSeconds
        )

        let expectedDistanceLimit = routeState == .onRoute
            ? configuration.offRouteDistanceMeters
            : configuration.recoveryDistanceMeters
        if let expected, expected.distanceFromRouteMeters <= expectedDistanceLimit {
            let shouldAdvance = expected.position.distanceAlongRouteMeters
                >= previousDistance - configuration.continuityBacktrackMeters
            if shouldAdvance {
                activeProjection = expected
                maximumDistanceAlongRouteMeters = max(
                    maximumDistanceAlongRouteMeters,
                    expected.position.distanceAlongRouteMeters
                )
            }
            alternativeCandidate = nil
            let recovered = routeState == .offRoute || routeState == .wrongFork
            routeState = recovered ? .rejoined : .onRoute
            let current = activeProjection ?? expected
            return snapshot(
                projection: current,
                state: routeState,
                hasReachedFinish: hasReachedFinish(at: current)
            )
        }

        let global = nearby.min {
            globalProjectionScore($0, sample: sample)
                < globalProjectionScore($1, sample: sample)
        }
        guard let global,
              global.distanceFromRouteMeters <= configuration.alternativeRouteDistanceMeters,
              plan.hasReliableCourse(sample),
              plan.courseDifference(for: global, sample: sample)
                <= configuration.compatibleCourseDifferenceDegrees,
              abs(global.position.distanceAlongRouteMeters - previousDistance)
                > minimumAlternativeProgressDelta else {
            alternativeCandidate = nil
            routeState = .offRoute
            return snapshot(
                projection: expected ?? previous,
                state: .offRoute,
                hasReachedFinish: false
            )
        }
        return handleAlternative(
            global,
            expected: expected,
            previous: previous,
            sample: sample
        )
    }

    private mutating func handleAlternative(
        _ global: RideRouteProjection,
        expected: RideRouteProjection?,
        previous: RideRouteProjection,
        sample: RideRouteGuidanceSample
    ) -> RideRouteGuidanceSnapshot {
        updateAlternativeCandidate(with: global, sample: sample)
        let confirmation = alternativeCandidate
        let confirmedWrongFork = confirmation.map {
            $0.sampleCount >= configuration.wrongForkSampleCount
                && $0.elapsedSeconds(at: sample.observedAt)
                    >= configuration.wrongForkConfirmationSeconds
                && $0.distanceMeters(to: sample.coordinate)
                    >= configuration.wrongForkConfirmationDistanceMeters
        } ?? false
        let mayRejoin = !isInsideProtectedFork
        let confirmedRejoin = confirmation.map {
            $0.sampleCount >= configuration.wrongForkSampleCount
                && $0.elapsedSeconds(at: sample.observedAt)
                    >= configuration.wrongForkConfirmationSeconds
                && $0.distanceMeters(to: sample.coordinate)
                    >= configuration.wrongForkConfirmationDistanceMeters
                && ($0.elapsedSeconds(at: sample.observedAt)
                    >= configuration.rejoinConfirmationSeconds
                    || $0.distanceMeters(to: sample.coordinate)
                        >= configuration.rejoinConfirmationDistanceMeters)
        } ?? false
        if mayRejoin, confirmedRejoin {
            activeProjection = global
            maximumDistanceAlongRouteMeters = max(
                maximumDistanceAlongRouteMeters,
                global.position.distanceAlongRouteMeters
            )
            alternativeCandidate = nil
            routeState = .rejoined
            return snapshot(
                projection: global,
                state: .rejoined,
                hasReachedFinish: hasReachedFinish(at: global)
            )
        }
        routeState = confirmedWrongFork ? .wrongFork : .offRoute
        return snapshot(
            projection: expected ?? previous,
            state: routeState,
            hasReachedFinish: false
        )
    }
}

private extension RideRouteGuidanceSession {
    private func expectedProjection(
        from projections: [RideRouteProjection],
        previous: RideRouteProjection,
        sample: RideRouteGuidanceSample,
        elapsedSeconds: TimeInterval
    ) -> RideRouteProjection? {
        let previousDistance = previous.position.distanceAlongRouteMeters
        let maximumAdvance = plausibleAdvanceMeters(for: sample, elapsedSeconds: elapsedSeconds)
        let continuityWeight = progressContinuityWeight(after: previousDistance)
        return projections.filter {
            let delta = $0.position.distanceAlongRouteMeters - previousDistance
            return delta >= -configuration.continuityBacktrackMeters
                && delta <= maximumAdvance
        }.min {
            projectionScore(
                $0,
                from: previous,
                sample: sample,
                continuityWeight: continuityWeight
            ) < projectionScore(
                $1,
                from: previous,
                sample: sample,
                continuityWeight: continuityWeight
            )
        }
    }

    private func plausibleAdvanceMeters(
        for sample: RideRouteGuidanceSample,
        elapsedSeconds: TimeInterval
    ) -> Double {
        let routeLimit = !isInsideProtectedFork
            ? configuration.continuityLookAheadMeters
            : configuration.forkDivergenceLookAheadMeters
        let motionLimit = max(
            Constants.minimumPlausibleAdvanceMeters,
            sample.speedKilometersPerHour / 3.6
                * elapsedSeconds * Constants.plausibleAdvanceMultiplier
                + Constants.plausibleAdvanceToleranceMeters
        )
        return min(routeLimit, motionLimit)
    }

    private var minimumAlternativeProgressDelta: Double {
        !isInsideProtectedFork
            ? configuration.continuityLookAheadMeters
            : configuration.forkDivergenceLookAheadMeters
    }

    private var isInsideProtectedFork: Bool {
        guard let protectedForkRange else { return false }
        return maximumDistanceAlongRouteMeters
            >= protectedForkRange.lowerBound - configuration.forkProximityMeters
            && maximumDistanceAlongRouteMeters <= protectedForkRange.upperBound
    }

    private mutating func updateProtectedForkRange(after distanceMeters: Double) {
        if let protectedForkRange,
           maximumDistanceAlongRouteMeters > protectedForkRange.upperBound {
            self.protectedForkRange = nil
        }
        guard protectedForkRange == nil,
              let decision = plan.nextDecision(after: distanceMeters),
              decision.isFork else { return }
        let forkDistance = distanceMeters + decision.distanceMeters
        protectedForkRange = forkDistance ... min(
            forkDistance + configuration.forkDivergenceLookAheadMeters,
            plan.totalDistanceMeters
        )
    }

    private func progressContinuityWeight(after distanceMeters: Double) -> Double {
        plan.nextDecision(after: distanceMeters)?.isFork == true
            ? Constants.forkProgressContinuityWeight
            : Constants.progressContinuityWeight
    }

    private func initialProjection(
        from projections: [RideRouteProjection],
        sample: RideRouteGuidanceSample
    ) -> RideRouteProjection {
        projections.min {
            let lhs = globalProjectionScore($0, sample: sample)
            let rhs = globalProjectionScore($1, sample: sample)
            if lhs == rhs {
                return $0.position.distanceAlongRouteMeters < $1.position.distanceAlongRouteMeters
            }
            return lhs < rhs
        } ?? projections[0]
    }

    private func projectionScore(
        _ projection: RideRouteProjection,
        from previous: RideRouteProjection,
        sample: RideRouteGuidanceSample,
        continuityWeight: Double
    ) -> Double {
        let progressDelta = abs(
            projection.position.distanceAlongRouteMeters
                - previous.position.distanceAlongRouteMeters
        )
        return projection.distanceFromRouteMeters
            + progressDelta * continuityWeight
            + plan.courseDifference(for: projection, sample: sample)
                * Constants.courseWeight
    }

    private func globalProjectionScore(
        _ projection: RideRouteProjection,
        sample: RideRouteGuidanceSample
    ) -> Double {
        projection.distanceFromRouteMeters
            + plan.courseDifference(for: projection, sample: sample)
                * Constants.courseWeight
    }

    private mutating func updateAlternativeCandidate(
        with projection: RideRouteProjection,
        sample: RideRouteGuidanceSample
    ) {
        guard var candidate = alternativeCandidate,
              candidate.matches(projection, configuration: configuration) else {
            alternativeCandidate = AlternativeCandidate(
                projection: projection,
                firstCoordinate: sample.coordinate,
                firstObservedAt: sample.observedAt,
                sampleCount: 1
            )
            return
        }
        candidate.projection = projection
        candidate.sampleCount += 1
        alternativeCandidate = candidate
    }

    private func hasReachedFinish(at projection: RideRouteProjection) -> Bool {
        guard let startingDistanceMeters else { return false }
        let advancedDistance = maximumDistanceAlongRouteMeters - startingDistanceMeters
        let requiredAdvance = min(
            configuration.minimumArrivalAdvanceMeters,
            plan.totalDistanceMeters - startingDistanceMeters
        )
        return advancedDistance > .zero
            && advancedDistance >= requiredAdvance
            && plan.totalDistanceMeters - projection.position.distanceAlongRouteMeters
                <= configuration.arrivalDistanceMeters
    }

    private func snapshot(
        projection: RideRouteProjection,
        state: RideRouteGuidanceRouteState,
        hasReachedFinish: Bool
    ) -> RideRouteGuidanceSnapshot {
        let progressDistance = max(
            maximumDistanceAlongRouteMeters,
            projection.position.distanceAlongRouteMeters
        )
        let corridor = plan.corridor(from: progressDistance)
        return RideRouteGuidanceSnapshot(
            projection: projection,
            completedRange: RideRouteDistanceRange(
                lowerBoundMeters: .zero,
                upperBoundMeters: progressDistance
            ),
            activeCorridorRange: corridor,
            futureRange: RideRouteDistanceRange(
                lowerBoundMeters: corridor.upperBoundMeters,
                upperBoundMeters: plan.totalDistanceMeters
            ),
            activeCorridorSlices: plan.slices(in: corridor),
            directionalIndicators: plan.indicators(in: corridor),
            decision: plan.nextDecision(after: progressDistance),
            routeState: state,
            hasReachedFinish: hasReachedFinish
        )
    }
}
