struct RoutePersistenceRuntimeState {
    enum SaveOperation {
        case plannedRoute
        case completedRoute
    }

    private(set) var selectedRouteNeedsSave = false
    private(set) var status = RideNavigationRoutePersistenceState.idle
    private(set) var closeAfterSave = false
    private(set) var activeSave: SaveOperation?

    mutating func selectImportedRoute() {
        selectedRouteNeedsSave = true
        status = .idle
        activeSave = nil
    }

    mutating func selectSavedRoute() {
        selectedRouteNeedsSave = false
        status = .saved
        activeSave = nil
    }

    mutating func beginPlannedRouteSave() {
        activeSave = .plannedRoute
        status = .saving
    }

    mutating func completePlannedRouteSave() {
        selectedRouteNeedsSave = false
        activeSave = nil
        status = .saved
    }

    mutating func beginCompletedRouteSave() {
        activeSave = .completedRoute
        status = .saving
    }

    mutating func requestCloseAfterSave() {
        closeAfterSave = true
    }

    mutating func completeCompletedRouteSave() -> Bool {
        activeSave = nil
        status = .saved
        let shouldClose = closeAfterSave
        closeAfterSave = false
        return shouldClose
    }

    mutating func fail(_ message: String) {
        activeSave = nil
        status = .failed(message: message)
    }

    mutating func cancelTransientSave() {
        guard activeSave == .plannedRoute else { return }
        activeSave = nil
        status = .failed(message: "The imported GPX save was interrupted. Try again before starting.")
    }

    mutating func clearFailure() {
        guard case .failed = status else { return }
        status = .idle
        activeSave = nil
    }

    mutating func reset() {
        self = Self()
    }
}
