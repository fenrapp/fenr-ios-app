import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    func updateTrailGuidance(with sample: RideRouteGuidanceSample) {
        guard let plan = trailGuidance.snapshot.plan,
              let guidanceSnapshot = trailGuidance.update(with: sample) else { return }
        let progressDistance = guidanceSnapshot.completedRange.upperBoundMeters
        trailMap.advanceCompletion(to: progressDistance)
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
        if trailGuidance.presentArrivalIfNeeded(for: guidanceSnapshot) {
            replaceFeedbackTask { [guidance] in await guidance.notifySuccess() }
        }
    }

    private func handleTrailRouteState(_ routeState: RideRouteGuidanceRouteState) {
        switch trailGuidance.routeStateAction(for: routeState) {
        case .none:
            if routeState == .onRoute || routeState == .rejoined {
                didAnnounceOffRoute = false
            }
        case .announceOffRoute:
            didAnnounceOffRoute = true
            announce(String(localized: .rideNavigationAnnouncementOffTrail))
            replaceFeedbackTask { [guidance] in await guidance.notifyWarning() }
        case .announceWrongFork:
            didAnnounceOffRoute = true
            announce(String(localized: .rideNavigationAnnouncementWrongDirection))
            replaceFeedbackTask { [guidance] in await guidance.notifyWarning() }
        case .announceRejoined:
            didAnnounceOffRoute = false
            announce(String(localized: .rideNavigationAnnouncementBackOnTrail))
        }
    }

    private func handleTrailDecision(_ decision: RideRouteGuidanceDecision?) {
        guard let decision,
              decision.distanceMeters <= Constants.voiceDecisionDistanceMeters,
              trailGuidance.shouldAnnounceDecision(decision) else { return }
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
        guard let route = planningController.snapshot.selectedRoute else { return }
        let direction = planningController.snapshot.selectedDirection
        let generation = operations.begin(.trailPreparation)
        let lifecycle = operations.lifecycleGeneration
        trailGuidance.beginPreparation(
            routeID: route.id,
            direction: direction,
            startAfterPreparation: startAfterPreparation
        )
        errorText = nil
        library.clearError()
        render()
        let trailGuidance = trailGuidance
        let trailMapPreparer = trailMapPreparer
        trailPreparationTask = Task { [weak self] in
            async let guidancePlan = trailGuidance.makePlan(for: route, direction: direction)
            async let mapPlan = trailMapPreparer.prepare(route: route, direction: direction)
            let (plan, preparedMap) = await (guidancePlan, mapPlan)
            guard !Task.isCancelled,
                  let self,
                  operations.isCurrent(
                      .trailPreparation,
                      generation: generation,
                      lifecycle: lifecycle
                  ),
                  isStarted,
                  planningController.snapshot.selectedRoute?.id == route.id,
                  planningController.snapshot.selectedDirection == direction else { return }
            if let preparedMap {
                trailMap.apply(preparedMap)
            }
            let shouldStart = trailGuidance.acceptPreparedPlan(plan)
            if plan == nil || preparedMap == nil {
                errorText = String(localized: .rideNavigationInsufficientConnectedPoints)
                render()
                return
            }
            if shouldStart {
                resolveTrailEntryAndStart()
            } else {
                cameraMode = .overview(trailMap.overviewCoordinates)
                render()
            }
        }
    }

    func startSelectedTrailRoute() {
        guard let route = planningController.snapshot.selectedRoute,
              !library.snapshot.persistence.status.isSaving else { return }
        let guidanceSnapshot = trailGuidance.snapshot
        if guidanceSnapshot.isPreparing {
            trailGuidance.requestStartAfterPreparation()
            render()
            return
        }
        if library.snapshot.persistence.selectedRouteNeedsSave {
            savePlannedRouteBeforeStart(route)
            return
        }
        guard guidanceSnapshot.routeID == route.id,
              guidanceSnapshot.direction == planningController.snapshot.selectedDirection,
              guidanceSnapshot.plan != nil else {
            prepareTrailPreview(startAfterPreparation: true)
            return
        }
        resolveTrailEntryAndStart()
    }

    public func selectTrailDirection(_ direction: RideNavigationTrailDirection) {
        trailGuidance.dismissEntryPrompt()
        let routeDirection: RideRouteDirection = direction == .forward ? .forward : .reverse
        guard planningController.snapshot.selectedDirection != routeDirection else {
            guard let plan = trailGuidance.snapshot.plan else {
                prepareTrailPreview(startAfterPreparation: true)
                return
            }
            beginTrailFollowing(plan: plan, projection: nearestEntryProjection(in: plan))
            return
        }
        planningController.setDirection(routeDirection)
        trailMap.reset()
        trailGuidance.reset()
        prepareTrailPreview(startAfterPreparation: true)
    }

    public func cancelTrailDirectionSelection() {
        trailGuidance.dismissEntryPrompt()
        render()
    }

    public func finishAfterTrailArrival() {
        guard trailGuidance.confirmArrival() else { return }
        finishActivity(reason: .trailComplete)
    }

    public func keepRidingAfterTrailArrival() {
        guard trailGuidance.keepRidingAfterArrival() else { return }
        render()
    }

    private func savePlannedRouteBeforeStart(_ route: RideRoute) {
        errorText = nil
        library.clearError()
        library.savePlannedRoute(route)
        render()
    }

    private func resolveTrailEntryAndStart() {
        guard let plan = trailGuidance.snapshot.plan else { return }
        guard let sample = trailGuidanceSample else {
            beginTrailFollowing(plan: plan, projection: nil)
            return
        }
        guard let match = plan.entryMatch(for: sample) else {
            if let start = plan.coordinate(atDistanceMeters: .zero) {
                trailGuidance.startSession(at: nil)
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
            trailGuidance.presentEntryPrompt(RideNavigationTrailEntryPrompt(
                title: String(localized: .rideNavigationFollowReverseTitle),
                detail: String(localized: .rideNavigationFollowReverseDetail),
                availableDirections: [.reverse, .forward]
            ))
            render()
        case .ambiguous:
            trailGuidance.presentEntryPrompt(RideNavigationTrailEntryPrompt(
                title: String(localized: .rideNavigationChooseTrailDirection),
                detail: String(localized: .rideNavigationChooseTrailDirectionDetail),
                availableDirections: [.forward, .reverse]
            ))
            render()
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
        let date = now()
        trailMap.resetCompletion()
        trailGuidance.startSession(at: projection)
        startBreadcrumb(at: date)
        activityStartedAt = date
        activity = .following
        planningController.clearRoadPlan()
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        screen = .map
        startClock()
        if let sample = trailGuidanceSample {
            updateTrailGuidance(with: sample)
        }
        render()
        announce(String(localized: .rideNavigationAnnouncementEnduroStarted))
    }

    var trailGuidanceSample: RideRouteGuidanceSample? {
        guard let coordinate = locationSnapshot.coordinate else { return nil }
        return RideRouteGuidanceSample(
            coordinate: coordinate,
            horizontalAccuracyMeters: locationSnapshot.horizontalAccuracyMeters,
            courseDegrees: locationSnapshot.courseDegrees,
            courseAccuracyDegrees: locationSnapshot.courseAccuracyDegrees,
            speedKilometersPerHour: latestDeviceSpeedKilometersPerHour ?? .zero,
            observedAt: locationSnapshot.observedAt ?? now()
        )
    }
}
