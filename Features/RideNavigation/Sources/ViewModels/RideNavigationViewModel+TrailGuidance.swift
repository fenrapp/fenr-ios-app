@MainActor
extension RideNavigationViewModel {
    func prepareTrailPreview(startAfterPreparation: Bool = false) {
        activityController.updatePreferences(roadRoutePreferences)
        activityController.prepareTrailPreview(startAfterPreparation: startAfterPreparation)
        render()
    }

    func startSelectedTrailRoute() {
        activityController.updatePreferences(roadRoutePreferences)
        activityController.startSelectedTrailRoute()
        render()
    }

    public func selectTrailDirection(_ direction: RideNavigationTrailDirection) {
        activityController.selectTrailDirection(direction)
        render()
    }

    public func cancelTrailDirectionSelection() {
        activityController.cancelTrailDirectionSelection()
        render()
    }

    public func finishAfterTrailArrival() {
        if let update = activityController.finishAfterTrailArrival() { receiveActivityUpdate(update) }
    }

    public func keepRidingAfterTrailArrival() {
        activityController.keepRidingAfterTrailArrival()
        render()
    }
}
