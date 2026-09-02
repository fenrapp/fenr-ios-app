import Foundation

public struct RideRouteProjectionSelector: Sendable {
    struct ExpectedInput: Sendable {
        let projections: [RideRouteProjection]
        let previous: RideRouteProjection
        let sample: RideRouteGuidanceSample
        let elapsedSeconds: TimeInterval
        let isInsideProtectedFork: Bool
        let plan: RideRouteGuidancePlan
        let configuration: RideRouteGuidanceConfiguration
    }

    public init() {}

    func initial(
        from projections: [RideRouteProjection],
        sample: RideRouteGuidanceSample,
        plan: RideRouteGuidancePlan
    ) -> RideRouteProjection {
        projections.min {
            let lhs = globalScore($0, sample: sample, plan: plan)
            let rhs = globalScore($1, sample: sample, plan: plan)
            if lhs == rhs {
                return $0.position.distanceAlongRouteMeters < $1.position.distanceAlongRouteMeters
            }
            return lhs < rhs
        } ?? projections[0]
    }

    func expected(_ input: ExpectedInput) -> RideRouteProjection? {
        let previousDistance = input.previous.position.distanceAlongRouteMeters
        let maximumAdvance = plausibleAdvanceMeters(
            for: input.sample,
            elapsedSeconds: input.elapsedSeconds,
            isInsideProtectedFork: input.isInsideProtectedFork,
            configuration: input.configuration
        )
        let continuityWeight = input.plan.nextDecision(after: previousDistance)?.isFork == true
            ? Constants.forkProgressContinuityWeight
            : Constants.progressContinuityWeight
        return input.projections.filter {
            let delta = $0.position.distanceAlongRouteMeters - previousDistance
            return delta >= -input.configuration.continuityBacktrackMeters && delta <= maximumAdvance
        }.min {
            score(
                $0,
                from: input.previous,
                sample: input.sample,
                continuityWeight: continuityWeight,
                plan: input.plan
            ) < score(
                $1,
                from: input.previous,
                sample: input.sample,
                continuityWeight: continuityWeight,
                plan: input.plan
            )
        }
    }

    func global(
        from projections: [RideRouteProjection],
        sample: RideRouteGuidanceSample,
        plan: RideRouteGuidancePlan
    ) -> RideRouteProjection? {
        projections.min {
            globalScore($0, sample: sample, plan: plan)
                < globalScore($1, sample: sample, plan: plan)
        }
    }

    func minimumAlternativeProgressDelta(
        isInsideProtectedFork: Bool,
        configuration: RideRouteGuidanceConfiguration
    ) -> Double {
        isInsideProtectedFork
            ? configuration.forkDivergenceLookAheadMeters
            : configuration.continuityLookAheadMeters
    }

    private func plausibleAdvanceMeters(
        for sample: RideRouteGuidanceSample,
        elapsedSeconds: TimeInterval,
        isInsideProtectedFork: Bool,
        configuration: RideRouteGuidanceConfiguration
    ) -> Double {
        let routeLimit = isInsideProtectedFork
            ? configuration.forkDivergenceLookAheadMeters
            : configuration.continuityLookAheadMeters
        let motionLimit = max(
            Constants.minimumPlausibleAdvanceMeters,
            sample.speedKilometersPerHour / 3.6
                * elapsedSeconds * Constants.plausibleAdvanceMultiplier
                + Constants.plausibleAdvanceToleranceMeters
        )
        return min(routeLimit, motionLimit)
    }

    private func score(
        _ projection: RideRouteProjection,
        from previous: RideRouteProjection,
        sample: RideRouteGuidanceSample,
        continuityWeight: Double,
        plan: RideRouteGuidancePlan
    ) -> Double {
        let progressDelta = abs(
            projection.position.distanceAlongRouteMeters
                - previous.position.distanceAlongRouteMeters
        )
        return projection.distanceFromRouteMeters
            + progressDelta * continuityWeight
            + plan.courseDifference(for: projection, sample: sample) * Constants.courseWeight
    }

    private func globalScore(
        _ projection: RideRouteProjection,
        sample: RideRouteGuidanceSample,
        plan: RideRouteGuidancePlan
    ) -> Double {
        projection.distanceFromRouteMeters
            + plan.courseDifference(for: projection, sample: sample) * Constants.courseWeight
    }

    private enum Constants {
        static let minimumPlausibleAdvanceMeters = 20.0
        static let plausibleAdvanceMultiplier = 2.0
        static let plausibleAdvanceToleranceMeters = 10.0
        static let progressContinuityWeight = 0.05
        static let forkProgressContinuityWeight = 2.0
        static let courseWeight = 0.15
    }
}
