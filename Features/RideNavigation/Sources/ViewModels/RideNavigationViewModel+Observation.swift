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
        activityController.receiveLocation(
            locationSnapshot, speedKilometersPerHour: sample.kilometersPerHour, preferences: roadRoutePreferences
        )
        if case .follow = cameraMode { cameraMode = followCamera }
        render()
    }

    var activeRoadStep: RoadNavigationStep? {
        guard let route = planningController.snapshot.roadRoute,
              route.steps.indices.contains(activityController.snapshot.activeRoadStepIndex) else { return nil }
        return route.steps[activityController.snapshot.activeRoadStepIndex]
    }

    func roadStepDistanceToManeuver(_ step: RoadNavigationStep) -> Double? {
        guard let location = locationSnapshot.coordinate, let end = step.points.last else { return nil }
        return RideRouteGeometry.distanceMeters(from: location, to: end)
    }

    func roadStepTargetBearing(_ step: RoadNavigationStep) -> Double? {
        guard let location = locationSnapshot.coordinate, let target = step.points.last else { return nil }
        return RideRouteGeometry.bearingDegrees(from: location, to: target)
    }

    func startLocationObservation() {
        guard locationObservationTask == nil, miniCompletionTitle == nil else { return }
        locationObservationGeneration &+= 1
        let generation = locationObservationGeneration
        let lifecycle = lifecycleGeneration
        let observeDeviceSpeed = dependencies.observeDeviceSpeed
        locationObservationTask = Task { [weak self] in
            let stream = await observeDeviceSpeed.execute()
            for await sample in stream where !Task.isCancelled {
                guard let self, isStarted, lifecycleGeneration == lifecycle,
                      locationObservationGeneration == generation else { return }
                receiveLocation(sample)
            }
        }
    }

    func stopLocationObservation() {
        locationObservationGeneration &+= 1
        locationObservationTask?.cancel()
        locationObservationTask = nil
    }

    func startVehicleObservation() {
        guard observationTask == nil else { return }
        vehicleObservationGeneration &+= 1
        let generation = vehicleObservationGeneration
        let lifecycle = lifecycleGeneration
        let session = dependencies.vehicleSession
        observationTask = Task { [weak self] in
            let stream = await session.observe()
            for await snapshot in stream where !Task.isCancelled {
                guard let self, isStarted, lifecycleGeneration == lifecycle,
                      vehicleObservationGeneration == generation else { return }
                receiveVehicleSnapshot(snapshot)
            }
        }
    }

    func stopVehicleObservation() {
        vehicleObservationGeneration &+= 1
        observationTask?.cancel()
        observationTask = nil
    }

    func startSettingsObservation(lifecycle: UInt) {
        guard settingsObservationTask == nil else { return }
        settingsObservationGeneration &+= 1
        let generation = settingsObservationGeneration
        let observeSettings = dependencies.observeSettings
        settingsObservationTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await snapshot in stream where !Task.isCancelled {
                guard let self, isStarted, lifecycleGeneration == lifecycle,
                      settingsObservationGeneration == generation else { return }
                receiveSettingsSnapshot(snapshot)
            }
        }
    }

    func synchronizePresentationObservations() {
        activityController.setPresentationMode(presentationMode)
        switch presentationMode {
        case .hidden:
            stopVehicleObservation()
            stopLocationObservation()
        case .fullScreen:
            guard screen != .summary else {
                stopVehicleObservation()
                stopLocationObservation()
                return
            }
            startLocationObservation()
            startVehicleObservation()
        case .mini:
            stopVehicleObservation()
            startLocationObservation()
        }
    }
}
