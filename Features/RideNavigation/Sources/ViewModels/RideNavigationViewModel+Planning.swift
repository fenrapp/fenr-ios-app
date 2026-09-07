import EnvironmentDomain
import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    public func updateSearchQuery(_ value: String) {
        clearPlanningFeedback()
        planningController.updateSearchQuery(value, near: locationSnapshot.coordinate)
        render()
    }

    public func search() {
        planningController.search(near: locationSnapshot.coordinate)
        render()
    }

    public func selectSearchResult(id: UUID) {
        guard let destination = planningController.snapshot.searchResults.first(where: { $0.id == id }),
              let origin = locationSnapshot.coordinate else {
            errorText = String(localized: .rideNavigationCurrentLocationRequired)
            render()
            return
        }
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: true)
    }

    func calculateRoadPreview(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        showsSearchLoading: Bool
    ) {
        clearPlanningFeedback()
        planningController.preview(
            from: origin, to: destination, preferences: roadRoutePreferences,
            showsSearchLoading: showsSearchLoading
        )
        render()
    }

    func recalculatePreviewRoutes(from origin: GeographicCoordinate, to destination: NavigationPlace) {
        clearPlanningFeedback()
        planningController.recalculatePreview(from: origin, to: destination, preferences: roadRoutePreferences)
        render()
    }

    public func selectRoadRouteOption(_ index: Int) {
        guard planningController.selectRoadOption(index),
              let route = planningController.snapshot.roadRoute else { return }
        resetRoadStepGuidance()
        cameraMode = .overview(mapMapper.coordinates(route.points))
        render()
    }

    public func findTrailExit() {
        guard activity == .following, planningController.snapshot.selectedRoute != nil,
              let origin = locationSnapshot.coordinate else {
            errorText = String(localized: .rideNavigationCurrentLocationRequiredForExit)
            render()
            return
        }
        clearPlanningFeedback()
        planningController.findTrailExit(from: origin, preferences: roadRoutePreferences)
        render()
    }

    public func cancelTrailExitPreview() {
        planningController.cancelTrailExitPreview()
        cameraMode = followCamera
        render()
    }

    public func startTrailExit() {
        guard activity == .following, planningController.selectTrailExit() else { return }
        resetRoadStepGuidance()
        activity = .navigating
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        clearPlanningFeedback()
        render()
        announce(String(localized: .rideNavigationAnnouncementExitStarted))
    }

    public func resumeGPX() {
        guard activity == .navigating, planningController.snapshot.roadNavigationPurpose == .trailExit,
              planningController.snapshot.selectedRoute != nil else { return }
        planningController.clearRoadPlan()
        resetRoadStepGuidance()
        activity = .following
        trailProgress = nil
        didAnnounceOffRoute = false
        if !trailGuidance.snapshot.hasActiveSession { trailGuidance.startSession(at: nil) }
        if let sample = trailGuidanceSample { updateTrailGuidance(with: sample) }
        cameraMode = followCamera
        clearPlanningFeedback()
        render()
        announce(String(localized: .rideNavigationAnnouncementEnduroResumed))
    }

    func startApproachRoute(from origin: GeographicCoordinate, to start: GeographicCoordinate) {
        let destination = NavigationPlace(
            name: String(localized: planningController.snapshot.selectedDirection == .forward
                ? .rideNavigationTrailStart : .rideNavigationTrailFinish),
            detail: String(localized: .rideNavigationTrailApproachDetail), coordinate: start
        )
        clearPlanningFeedback()
        planningController.approach(from: origin, to: destination, preferences: roadRoutePreferences)
    }

    func clearPlanningFeedback() {
        errorText = nil
        library.clearError()
        planningController.clearError()
    }
}
