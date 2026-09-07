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
        activityController.resetRoadStepGuidance()
        cameraMode = .overview(dependencies.mapPresentationMapper.coordinates(route.points))
        render()
    }

    public func findTrailExit() {
        guard activityController.snapshot.activity == .following, planningController.snapshot.selectedRoute != nil,
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
        guard activityController.snapshot.activity == .following, planningController.selectTrailExit() else { return }
        activityController.resetRoadStepGuidance()
        activityController.continueRoadNavigation()
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        clearPlanningFeedback()
        render()
        activityController.announce(String(localized: .rideNavigationAnnouncementExitStarted))
    }

    public func resumeGPX() {
        guard activityController.snapshot.activity == .navigating,
              planningController.snapshot.roadNavigationPurpose == .trailExit,
              planningController.snapshot.selectedRoute != nil else { return }
        planningController.clearRoadPlan()
        activityController.resetRoadStepGuidance()
        activityController.resumeTrailFollowing()
        cameraMode = followCamera
        clearPlanningFeedback()
        render()
        activityController.announce(String(localized: .rideNavigationAnnouncementEnduroResumed))
    }

    func clearPlanningFeedback() {
        errorText = nil
        library.clearError()
        planningController.clearError()
        activityController.clearError()
    }
}
