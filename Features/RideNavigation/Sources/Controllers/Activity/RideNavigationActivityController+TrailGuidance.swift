import EnvironmentDomain
import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationActivityController {
    func updateTrailGuidance(with sample: RideRouteGuidanceSample) {
        guard let plan = dependencies.trailGuidance.snapshot.plan,
              let guidanceSnapshot = dependencies.trailGuidance.update(with: sample) else { return }
        let progressDistance = guidanceSnapshot.completedRange.upperBoundMeters
        dependencies.trailMap.advanceCompletion(to: progressDistance)
        let target = plan.coordinate(
            atDistanceMeters: progressDistance + Constants.enduroLookAheadMeters
        ) ?? guidanceSnapshot.projection.coordinate
        trailProgress = RideRouteProgress(
            distanceFromRouteMeters: guidanceSnapshot.projection.distanceFromRouteMeters,
            distanceAlongRouteMeters: progressDistance,
            remainingDistanceMeters: max(
                plan.totalDistanceMeters - progressDistance,
                .zero
            ),
            rejoinCoordinate: guidanceSnapshot.projection.coordinate,
            targetCoordinate: target,
            targetBearingDegrees: RideRouteGeometry.bearingDegrees(
                from: sample.coordinate,
                to: target
            )
        )
        handleTrailRouteState(guidanceSnapshot.routeState)
        handleTrailDecision(guidanceSnapshot.decision)
        if dependencies.trailGuidance.presentArrivalIfNeeded(for: guidanceSnapshot) {
            notifySuccess()
        }
    }

    private func handleTrailRouteState(_ routeState: RideRouteGuidanceRouteState) {
        switch dependencies.trailGuidance.routeStateAction(for: routeState) {
        case .none:
            if routeState == .onRoute || routeState == .rejoined {
                didAnnounceOffRoute = false
            }
        case .announceOffRoute:
            didAnnounceOffRoute = true
            announce(String(localized: .rideNavigationAnnouncementOffTrail))
            notifyWarning()
        case .announceWrongFork:
            didAnnounceOffRoute = true
            announce(String(localized: .rideNavigationAnnouncementWrongDirection))
            notifyWarning()
        case .announceRejoined:
            didAnnounceOffRoute = false
            announce(String(localized: .rideNavigationAnnouncementBackOnTrail))
        }
    }

    private func handleTrailDecision(_ decision: RideRouteGuidanceDecision?) {
        guard let decision,
              decision.distanceMeters <= Constants.voiceDecisionDistanceMeters,
              dependencies.trailGuidance.shouldAnnounceDecision(decision) else { return }
        switch decision.direction {
        case .left:
            announce(String(localized: .rideNavigationKeepLeft))
        case .right:
            announce(String(localized: .rideNavigationKeepRight))
        case .straight:
            announce(String(localized: .rideNavigationContinueStraight))
        }
    }

    func prepareTrailPreview(startAfterPreparation: Bool = false) {
        guard let route = dependencies.planning.snapshot.selectedRoute else { return }
        let direction = dependencies.planning.snapshot.selectedDirection
        contextGeneration &+= 1
        preparationGeneration &+= 1
        trailPreparationTask?.cancel()
        let generation = preparationGeneration
        let lifecycle = lifecycleGeneration
        let context = contextGeneration
        dependencies.trailGuidance.beginPreparation(
            routeID: route.id,
            direction: direction,
            startAfterPreparation: startAfterPreparation
        )
        errorMessage = nil
        dependencies.library.clearError()
        publish()
        let trailGuidance = dependencies.trailGuidance
        let trailMapPreparer = dependencies.trailMapPreparer
        trailPreparationTask = Task { [weak self] in
            async let guidancePlan = trailGuidance.makePlan(for: route, direction: direction)
            async let mapPlan = trailMapPreparer.prepare(route: route, direction: direction)
            let (plan, preparedMap) = await (guidancePlan, mapPlan)
            guard !Task.isCancelled,
                  let self,
                  preparationGeneration == generation, lifecycleGeneration == lifecycle, contextGeneration == context,
                  isStarted,
                  dependencies.planning.snapshot.selectedRoute?.id == route.id,
                  dependencies.planning.snapshot.selectedDirection == direction else { return }
            if let preparedMap {
                dependencies.trailMap.apply(preparedMap)
            }
            let shouldStart = trailGuidance.acceptPreparedPlan(plan)
            if plan == nil || preparedMap == nil {
                errorMessage = String(localized: .rideNavigationInsufficientConnectedPoints)
                publish()
                return
            }
            if shouldStart {
                resolveTrailEntryAndStart()
            } else {
                publish(effect: .showTrailOverview, preparation: generation)
            }
        }
    }

    func startSelectedTrailRoute() {
        guard let route = dependencies.planning.snapshot.selectedRoute,
              !dependencies.library.snapshot.persistence.status.isSaving else { return }
        let guidanceSnapshot = dependencies.trailGuidance.snapshot
        if guidanceSnapshot.isPreparing {
            dependencies.trailGuidance.requestStartAfterPreparation()
            publish()
            return
        }
        if dependencies.library.snapshot.persistence.selectedRouteNeedsSave {
            savePlannedRouteBeforeStart(route)
            return
        }
        guard guidanceSnapshot.routeID == route.id,
              guidanceSnapshot.direction == dependencies.planning.snapshot.selectedDirection,
              guidanceSnapshot.plan != nil else {
            prepareTrailPreview(startAfterPreparation: true)
            return
        }
        resolveTrailEntryAndStart()
    }

    func selectTrailDirection(_ direction: RideNavigationTrailDirection) {
        dependencies.trailGuidance.dismissEntryPrompt()
        let routeDirection: RideRouteDirection = direction == .forward ? .forward : .reverse
        guard dependencies.planning.snapshot.selectedDirection != routeDirection else {
            guard let plan = dependencies.trailGuidance.snapshot.plan else {
                prepareTrailPreview(startAfterPreparation: true)
                return
            }
            beginTrailFollowing(plan: plan, projection: nearestEntryProjection(in: plan))
            return
        }
        dependencies.planning.setDirection(routeDirection)
        dependencies.trailMap.reset()
        dependencies.trailGuidance.reset()
        prepareTrailPreview(startAfterPreparation: true)
    }

    func cancelTrailDirectionSelection() {
        dependencies.trailGuidance.dismissEntryPrompt()
        publish()
    }

    func finishAfterTrailArrival() -> RideNavigationActivityUpdate? {
        guard dependencies.trailGuidance.confirmArrival() else { return nil }
        return finishActivity(reason: .trailComplete)
    }

    func keepRidingAfterTrailArrival() {
        guard dependencies.trailGuidance.keepRidingAfterArrival() else { return }
        publish()
    }

    private func savePlannedRouteBeforeStart(_ route: RideRoute) {
        errorMessage = nil
        dependencies.library.clearError()
        dependencies.library.savePlannedRoute(route)
        publish()
    }

    private func resolveTrailEntryAndStart() {
        guard let plan = dependencies.trailGuidance.snapshot.plan else { return }
        guard let sample = trailGuidanceSample else {
            beginTrailFollowing(plan: plan, projection: nil)
            return
        }
        guard let match = plan.entryMatch(for: sample) else {
            if let start = plan.coordinate(atDistanceMeters: .zero) {
                dependencies.trailGuidance.startSession(at: nil)
                startApproachRoute(from: sample.coordinate, to: start)
            } else {
                beginTrailFollowing(plan: plan, projection: nil)
            }
            return
        }
        switch match.classification {
        case .forward:
            beginTrailFollowing(plan: plan, projection: match.selectedProjection)
        case .reverse:
            dependencies.trailGuidance.presentEntryPrompt(RideNavigationTrailEntryPrompt(
                title: String(localized: .rideNavigationFollowReverseTitle),
                detail: String(localized: .rideNavigationFollowReverseDetail),
                availableDirections: [.reverse, .forward]
            ))
            publish()
        case .ambiguous:
            dependencies.trailGuidance.presentEntryPrompt(RideNavigationTrailEntryPrompt(
                title: String(localized: .rideNavigationChooseTrailDirection),
                detail: String(localized: .rideNavigationChooseTrailDirectionDetail),
                availableDirections: [.forward, .reverse]
            ))
            publish()
        }
    }

    func nearestEntryProjection(in plan: RideRouteGuidancePlan) -> RideRouteProjection? {
        guard let sample = trailGuidanceSample else { return nil }
        return plan.entryMatch(for: sample)?.selectedProjection
            ?? plan.entryMatch(for: sample)?.projections.first
    }

    func beginTrailFollowing(
        plan: RideRouteGuidancePlan,
        projection: RideRouteProjection?
    ) {
        let date = dependencies.timing.now()
        dependencies.trailMap.resetCompletion()
        dependencies.trailGuidance.startSession(at: projection)
        startBreadcrumb(at: date)
        activityStartedAt = date
        activity = .following
        dependencies.planning.clearRoadPlan()
        completion = nil
        synchronizeClock()
        if let sample = trailGuidanceSample {
            updateTrailGuidance(with: sample)
        }
        publish(effect: .showActiveMap)
        announce(String(localized: .rideNavigationAnnouncementEnduroStarted))
    }

    var trailGuidanceSample: RideRouteGuidanceSample? {
        guard let coordinate = locationSnapshot.coordinate else { return nil }
        return RideRouteGuidanceSample(
            coordinate: coordinate,
            horizontalAccuracyMeters: locationSnapshot.horizontalAccuracyMeters,
            courseDegrees: locationSnapshot.courseDegrees,
            courseAccuracyDegrees: locationSnapshot.courseAccuracyDegrees,
            speedKilometersPerHour: locationSpeed ?? .zero,
            observedAt: locationSnapshot.observedAt ?? dependencies.timing.now()
        )
    }
    private func startApproachRoute(from origin: GeographicCoordinate, to start: GeographicCoordinate) {
        let destination = NavigationPlace(
            name: String(localized: dependencies.planning.snapshot.selectedDirection == .forward
                ? .rideNavigationTrailStart : .rideNavigationTrailFinish),
            detail: String(localized: .rideNavigationTrailApproachDetail), coordinate: start
        )
        dependencies.planning.approach(from: origin, to: destination, preferences: preferences)
    }
}
