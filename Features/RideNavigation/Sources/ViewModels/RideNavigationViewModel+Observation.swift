import BikeDomain
import EnvironmentDomain
import Foundation
import RideNavigationDomain
import VehicleSession

@MainActor
extension RideNavigationViewModel {
    func receiveVehicleSnapshot(_ snapshot: VehicleSessionSnapshot) {
        vehicleSnapshot = snapshot
        updateVehicleMetricCache(from: snapshot)
        render()
    }

    func receiveLocation(_ sample: DeviceSpeedSample) {
        latestDeviceSpeedKilometersPerHour = sample.kilometersPerHour
        locationSnapshot = RideNavigationLocationSnapshot(
            coordinate: sample.coordinate,
            horizontalAccuracyMeters: sample.horizontalAccuracyMeters,
            courseDegrees: sample.courseDegrees,
            courseAccuracyDegrees: sample.courseAccuracyDegrees,
            altitudeMeters: sample.altitudeMeters,
            verticalAccuracyMeters: sample.verticalAccuracyMeters,
            observedAt: sample.observedAt
        )
        processLocationUpdate()
    }

    func processLocationUpdate() {
        if let point = locationGeometry.routePoint(from: locationSnapshot) {
            if activity == .recording {
                recorder.append(point)
                scheduleDraftSave()
            } else if activity == .following || activity == .navigating {
                breadcrumbRecorder.append(point)
            }
        }
        updateGuidanceStatus()
        if case .follow = cameraMode {
            cameraMode = followCamera
        }
        render()
    }

    func updateGuidanceStatus() {
        if activity == .navigating,
           let location = locationSnapshot.coordinate {
            updateRoadStepProgress(from: location)
        }
        if activity == .navigating,
           let location = locationSnapshot.coordinate,
           let roadRoute,
           let distance = RideRouteGeometry.closestDistanceMeters(
               from: location,
               to: roadRoute.points
           ),
           distance > Constants.roadRerouteDistanceMeters {
            rerouteRoadNavigation(from: location)
        }
        if activity == .navigating,
           let location = locationSnapshot.coordinate,
           let finish = roadRoute?.points.last,
           RideRouteGeometry.distanceMeters(from: location, to: finish) <= Constants.arrivalDistanceMeters {
            if roadNavigationPurpose == .trailApproach {
                roadRoute = nil
                roadRoutes = []
                selectedDestination = nil
                roadNavigationPurpose = nil
                activity = .following
                trailProgress = nil
                resetRoadStepGuidance()
                didAnnounceOffRoute = false
                announce(String(localized: .rideNavigationAnnouncementTrailReached))
            } else if roadNavigationPurpose == .trailExit {
                finishActivity(reason: .exitPointReached)
            } else {
                finishActivity(reason: .destinationReached)
            }
            return
        }
        guard activity == .following, let sample = trailGuidanceSample else { return }
        updateTrailGuidance(with: sample)
    }

    func startClock() {
        guard presentationMode == .fullScreen, clockTask == nil else { return }
        let sleep = timing.sleep
        let generation = operations.begin(.clock)
        let lifecycle = operations.lifecycleGeneration
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await sleep(.seconds(1))
                } catch {
                    return
                }
                guard let self,
                      operations.isCurrent(.clock, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                render()
            }
        }
    }

    func stopClock() {
        operations.invalidate(.clock)
    }

    var activeRoadStep: RoadNavigationStep? {
        guard let roadRoute, roadRoute.steps.indices.contains(activeRoadStepIndex) else { return nil }
        return roadRoute.steps[activeRoadStepIndex]
    }

    func updateRoadStepProgress(from location: GeographicCoordinate) {
        guard let roadRoute, !roadRoute.steps.isEmpty else { return }
        activeRoadStepIndex = min(activeRoadStepIndex, roadRoute.steps.index(before: roadRoute.steps.endIndex))
        while roadRoute.steps.indices.contains(activeRoadStepIndex + 1) {
            let current = roadRoute.steps[activeRoadStepIndex]
            let next = roadRoute.steps[activeRoadStepIndex + 1]
            let distanceToCurrentEnd = current.points.last.map {
                RideRouteGeometry.distanceMeters(from: location, to: $0)
            } ?? .infinity
            let currentDistance = RideRouteGeometry.closestDistanceMeters(
                from: location,
                to: current.points
            ) ?? .infinity
            let nextDistance = RideRouteGeometry.closestDistanceMeters(
                from: location,
                to: next.points
            ) ?? .infinity
            let reachedManeuver = distanceToCurrentEnd <= Constants.roadStepAdvanceDistanceMeters
            let enteredNextStep = nextDistance <= Constants.roadStepAdvanceDistanceMeters
                && nextDistance + Constants.roadStepDistanceAdvantageMeters < currentDistance
            guard reachedManeuver || enteredNextStep else { break }
            activeRoadStepIndex += 1
        }
        guard announcedRoadStepIndex != activeRoadStepIndex,
              let instruction = activeRoadStep?.instruction,
              !instruction.isEmpty else { return }
        announcedRoadStepIndex = activeRoadStepIndex
        announce(instruction)
    }

    func roadStepDistanceToManeuver(_ step: RoadNavigationStep) -> Double? {
        guard let location = locationSnapshot.coordinate,
              let end = step.points.last else { return nil }
        return RideRouteGeometry.distanceMeters(from: location, to: end)
    }

    func roadStepTargetBearing(_ step: RoadNavigationStep) -> Double? {
        guard let location = locationSnapshot.coordinate,
              let target = step.points.last else { return nil }
        return RideRouteGeometry.bearingDegrees(from: location, to: target)
    }

    func rerouteRoadNavigation(from origin: GeographicCoordinate) {
        let date = now()
        if let lastRoadRerouteAt,
           date.timeIntervalSince(lastRoadRerouteAt) < Constants.minimumRerouteIntervalSeconds {
            return
        }
        guard let destination = selectedDestination else { return }
        lastRoadRerouteAt = date
        let generation = operations.begin(.route)
        let lifecycle = operations.lifecycleGeneration
        isRerouting = true
        render()
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let calculatedRoute = try await roadRouteCalculator.route(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                roadRoute = calculatedRoute
                roadRoutes = [calculatedRoute]
                selectedRoadRouteIndex = .zero
                resetRoadStepGuidance()
                isRerouting = false
                errorText = nil
                render()
                announce(String(localized: .rideNavigationAnnouncementRouteUpdated))
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      operations.isCurrent(.route, generation: generation, lifecycle: lifecycle),
                      isStarted else { return }
                isRerouting = false
                errorText = String(localized: .rideNavigationReroutingUnavailable)
                render()
            }
        }
    }

    func scheduleDraftSave() {
        draftSaveTask?.cancel()
        guard let route = recorder.snapshot(at: now()).route else { return }
        let routeLibrary = dependencies.routeLibrary
        let sleep = timing.sleep
        draftSaveTask = Task {
            do {
                try await sleep(.seconds(2))
                try Task.checkCancellation()
                try await routeLibrary.saveDraft(route)
            } catch {
                return
            }
        }
    }

    func announce(_ text: String) {
        guard !isVoiceMuted else { return }
        let generation = operations.begin(.voiceAnnouncement)
        voiceAnnouncementTask = Task { [guidance] in
            guard !Task.isCancelled else { return }
            await guidance.announce(text)
            _ = generation
        }
    }

    func startBreadcrumb(at date: Date) {
        breadcrumbRecorder.reset()
        breadcrumbRecorder.start(at: date, name: String(localized: .rideNavigationBreadcrumbName))
        trailProgress = nil
        didAnnounceOffRoute = false
        lastRoadRerouteAt = nil
        if let point = locationGeometry.routePoint(from: locationSnapshot) {
            breadcrumbRecorder.append(point)
        }
    }

    func replaceDraftPersistenceTask(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        _ = operations.begin(.draftPersistence)
        draftPersistenceTask = Task {
            await operation()
        }
    }

    func replaceGuidanceTask(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        _ = operations.begin(.guidance)
        guidanceTask = Task {
            await operation()
        }
    }

    func replaceFeedbackTask(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        _ = operations.begin(.feedback)
        feedbackTask = Task {
            await operation()
        }
    }

    func startLocationObservation() {
        guard locationObservationTask == nil, miniCompletionTitle == nil else { return }
        let observeDeviceSpeed = observeDeviceSpeed
        let generation = operations.begin(.locationObservation)
        let lifecycle = operations.lifecycleGeneration
        locationObservationTask = Task { [weak self] in
            let stream = await observeDeviceSpeed.execute()
            for await sample in stream where !Task.isCancelled {
                guard let self,
                      operations.isCurrent(
                          .locationObservation,
                          generation: generation,
                          lifecycle: lifecycle
                      ),
                      isStarted else { return }
                receiveLocation(sample)
            }
        }
    }

    func startVehicleObservation() {
        guard observationTask == nil else { return }
        let vehicleSession = vehicleSession
        let generation = operations.begin(.vehicleObservation)
        let lifecycle = operations.lifecycleGeneration
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream where !Task.isCancelled {
                guard let self,
                      operations.isCurrent(
                          .vehicleObservation,
                          generation: generation,
                          lifecycle: lifecycle
                      ),
                      isStarted else { return }
                receiveVehicleSnapshot(snapshot)
            }
        }
    }

    func startSettingsObservation(lifecycle: UInt) {
        guard settingsObservationTask == nil else { return }
        let observeSettings = observeSettings
        let generation = operations.begin(.settingsObservation)
        settingsObservationTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream where !Task.isCancelled {
                guard let self,
                      operations.isCurrent(
                          .settingsObservation,
                          generation: generation,
                          lifecycle: lifecycle
                      ),
                      isStarted else { return }
                guard appSettings != settings else { continue }
                receiveLoadedSettings(settings)
            }
        }
    }

    func synchronizePresentationObservations() {
        switch presentationMode {
        case .hidden:
            operations.invalidate(.vehicleObservation)
            operations.invalidate(.locationObservation)
            stopClock()
        case .fullScreen:
            guard screen != .summary else {
                operations.invalidate(.vehicleObservation)
                operations.invalidate(.locationObservation)
                stopClock()
                return
            }
            startLocationObservation()
            startVehicleObservation()
            if hasActiveSession {
                startClock()
            }
        case .mini:
            operations.invalidate(.vehicleObservation)
            stopClock()
            startLocationObservation()
        }
    }
}
