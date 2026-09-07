import EnvironmentDomain
import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationActivityController {
    func receiveLocation(
        _ location: RideNavigationLocationSnapshot,
        speedKilometersPerHour: Double?,
        preferences: RoadRoutePreferences
    ) {
        locationSnapshot = location
        locationSpeed = speedKilometersPerHour
        self.preferences = preferences
        if let point = dependencies.locationGeometry.routePoint(from: location) {
            if activity == .recording {
                recorder.append(point)
                scheduleDraftSave()
            } else if activity == .following || activity == .navigating {
                breadcrumbRecorder.append(point)
            }
        }
        updateGuidanceStatus()
        publish()
    }

    func updateGuidanceStatus() {
        if activity == .navigating,
           let location = locationSnapshot.coordinate {
            updateRoadStepProgress(from: location)
        }
        if activity == .navigating,
           let location = locationSnapshot.coordinate,
           let roadRoute = dependencies.planning.snapshot.roadRoute,
           let distance = RideRouteGeometry.closestDistanceMeters(
               from: location,
               to: roadRoute.points
           ),
           distance > Constants.roadRerouteDistanceMeters {
            dependencies.planning.reroute(from: location, preferences: preferences)
        }
        if activity == .navigating,
           let location = locationSnapshot.coordinate,
           let finish = dependencies.planning.snapshot.roadRoute?.points.last,
           RideRouteGeometry.distanceMeters(from: location, to: finish) <= Constants.arrivalDistanceMeters {
            if dependencies.planning.snapshot.roadNavigationPurpose == .trailApproach {
                dependencies.planning.clearRoadPlan()
                activity = .following
                trailProgress = nil
                resetRoadStepGuidance()
                didAnnounceOffRoute = false
                announce(String(localized: .rideNavigationAnnouncementTrailReached))
            } else if dependencies.planning.snapshot.roadNavigationPurpose == .trailExit {
                finishActivity(reason: .exitPointReached)
            } else {
                finishActivity(reason: .destinationReached)
            }
            return
        }
        guard activity == .following, let sample = trailGuidanceSample else { return }
        updateTrailGuidance(with: sample)
    }

    var activeRoadStep: RoadNavigationStep? {
        guard let roadRoute = dependencies.planning.snapshot.roadRoute,
              roadRoute.steps.indices.contains(activeRoadStepIndex) else { return nil }
        return roadRoute.steps[activeRoadStepIndex]
    }

    func updateRoadStepProgress(from location: GeographicCoordinate) {
        guard let roadRoute = dependencies.planning.snapshot.roadRoute, !roadRoute.steps.isEmpty else { return }
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

}
