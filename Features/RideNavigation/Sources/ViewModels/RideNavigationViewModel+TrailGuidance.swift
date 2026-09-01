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
            announce("You are off trail. Follow the arrow back to the track")
            replaceFeedbackTask { [guidance] in await guidance.notifyWarning() }
        case .announceWrongFork:
            didAnnounceOffRoute = true
            announce("Wrong direction. Return to the highlighted track")
            replaceFeedbackTask { [guidance] in await guidance.notifyWarning() }
        case .announceRejoined:
            didAnnounceOffRoute = false
            announce("Back on trail")
        }
    }

    private func handleTrailDecision(_ decision: RideRouteGuidanceDecision?) {
        guard let decision,
              decision.distanceMeters <= Constants.voiceDecisionDistanceMeters,
              trailGuidance.shouldAnnounceDecision(decision) else { return }
        switch decision.direction {
        case .left:
            announce("Keep left")
        case .right:
            announce("Keep right")
        case .straight:
            announce("Continue straight")
        }
    }

    func prepareTrailPreview(startAfterPreparation: Bool = false) {
        guard let route = selectedRoute else { return }
        let direction = selectedDirection
        let generation = operations.begin(.trailPreparation)
        let lifecycle = operations.lifecycleGeneration
        trailGuidance.beginPreparation(
            routeID: route.id,
            direction: direction,
            startAfterPreparation: startAfterPreparation
        )
        errorText = nil
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
                  selectedRoute?.id == route.id,
                  selectedDirection == direction else { return }
            if let preparedMap {
                trailMap.apply(preparedMap)
            }
            let shouldStart = trailGuidance.acceptPreparedPlan(plan)
            if plan == nil || preparedMap == nil {
                errorText = "This route does not contain enough connected points to navigate."
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
        guard let route = selectedRoute,
              !state.routePersistence.status.isSaving else { return }
        let guidanceSnapshot = trailGuidance.snapshot
        if guidanceSnapshot.isPreparing {
            trailGuidance.requestStartAfterPreparation()
            render()
            return
        }
        if state.routePersistence.selectedRouteNeedsSave {
            savePlannedRouteBeforeStart(route)
            return
        }
        guard guidanceSnapshot.routeID == route.id,
              guidanceSnapshot.direction == selectedDirection,
              guidanceSnapshot.plan != nil else {
            prepareTrailPreview(startAfterPreparation: true)
            return
        }
        resolveTrailEntryAndStart()
    }

    public func selectTrailDirection(_ direction: RideNavigationTrailDirection) {
        trailGuidance.dismissEntryPrompt()
        let routeDirection: RideRouteDirection = direction == .forward ? .forward : .reverse
        guard selectedDirection != routeDirection else {
            guard let plan = trailGuidance.snapshot.plan else {
                prepareTrailPreview(startAfterPreparation: true)
                return
            }
            beginTrailFollowing(plan: plan, projection: nearestEntryProjection(in: plan))
            return
        }
        selectedDirection = routeDirection
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
        let generation = operations.begin(.plannedRouteSave)
        let lifecycle = operations.lifecycleGeneration
        state.routePersistence.beginPlannedRouteSave()
        errorText = nil
        render()
        let routeLibrary = dependencies.routeLibrary
        plannedRouteSaveTask = Task { [weak self] in
            do {
                let routes = try await routeLibrary.saveAndReload(route)
                guard let self,
                      operations.isCurrent(
                          .plannedRouteSave,
                          generation: generation,
                          lifecycle: lifecycle
                      ),
                      isStarted,
                      selectedRoute?.id == route.id else { return }
                savedRoutes = routes
                state.routePersistence.completePlannedRouteSave()
                startSelectedTrailRoute()
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(
                          .plannedRouteSave,
                          generation: generation,
                          lifecycle: lifecycle
                      ),
                      isStarted else { return }
                state.routePersistence.fail(
                    "The imported GPX could not be saved. Try again before starting."
                )
                errorText = "The imported GPX could not be saved."
                render()
            }
        }
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
                title: "Follow in reverse?",
                detail: "Your direction is opposite to the planned track.",
                availableDirections: [.reverse, .forward]
            ))
            render()
        case .ambiguous:
            trailGuidance.presentEntryPrompt(RideNavigationTrailEntryPrompt(
                title: "Choose trail direction",
                detail: "The route overlaps here, so choose the direction you want to follow.",
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
        roadNavigationPurpose = nil
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        screen = .map
        startClock()
        if let sample = trailGuidanceSample {
            updateTrailGuidance(with: sample)
        }
        render()
        announce("Enduro navigation started")
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
