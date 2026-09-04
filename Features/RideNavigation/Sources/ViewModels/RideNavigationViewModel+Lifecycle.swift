import Foundation
import SettingsDomain

@MainActor
extension RideNavigationViewModel {
    public var hasActiveSession: Bool {
        [.following, .navigating, .recording, .paused].contains(activity)
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        let lifecycle = operations.startLifecycle()
        startLocationObservation()
        synchronizePresentationObservations()
        let routesGeneration = operations.begin(.initialRoutes)
        let routeLibrary = dependencies.routeLibrary
        loadingTask = Task { [weak self] in
            let routes = await routeLibrary.loadRoutes()
            guard !Task.isCancelled else { return }
            guard let self,
                  operations.isCurrent(
                      .initialRoutes,
                      generation: routesGeneration,
                      lifecycle: lifecycle
                  ),
                  isStarted else { return }
            receiveLoadedRoutes(routes)
        }
        let settingsGeneration = operations.begin(.initialSettings)
        let loadSettings = loadSettings
        settingsLoadingTask = Task { [weak self] in
            let settings = await loadSettings.execute()
            guard !Task.isCancelled else { return }
            guard let self,
                  operations.isCurrent(
                      .initialSettings,
                      generation: settingsGeneration,
                      lifecycle: lifecycle
                  ),
                  isStarted else { return }
            receiveLoadedSettings(settings)
            startSettingsObservation(lifecycle: lifecycle)
        }
    }

    public func stop() {
        isStarted = false
        trailGuidance.cancelPreparation()
        state.routePersistence.cancelTransientSave()
        operations.invalidateAll(preserving: [.completedRouteSave])
        observationTask?.cancel()
        observationTask = nil
        locationObservationTask?.cancel()
        locationObservationTask = nil
        clockTask?.cancel()
        clockTask = nil
        searchTask?.cancel()
        searchTask = nil
        routeTask?.cancel()
        routeTask = nil
        externalLinkTask?.cancel()
        externalLinkTask = nil
        trailExitTask?.cancel()
        trailExitTask = nil
        isCalculatingRoadRoutes = false
        isRerouting = false
        isFindingTrailExit = false
        draftSaveTask?.cancel()
        draftSaveTask = nil
        loadingTask?.cancel()
        loadingTask = nil
        settingsLoadingTask?.cancel()
        settingsLoadingTask = nil
        settingsObservationTask?.cancel()
        settingsObservationTask = nil
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        routeSaveTask?.cancel()
        routeSaveTask = nil
        routeDeletionTasks.values.forEach { $0.cancel() }
        routeDeletionTasks.removeAll()
        draftPersistenceTask?.cancel()
        draftPersistenceTask = nil
        guidanceTask?.cancel()
        guidanceTask = nil
        if viewState.isSearching {
            render(isSearching: false)
        }
    }

    public func setPresentationMode(_ mode: RideNavigationPresentationMode) {
        guard presentationMode != mode else { return }
        presentationMode = mode
        if mode == .fullScreen {
            miniCompletionTitle = nil
            frozenMiniMapScene = nil
        }
        guard isStarted else { return }
        synchronizePresentationObservations()
        render()
    }

    public var canMinimize: Bool {
        screen == .map && [.following, .navigating, .recording, .paused].contains(activity)
    }

    public func setMiniMapPosition(_ position: RideNavigationMiniViewState.Position) {
        let setting = MiniMapPosition(position)
        guard appSettings.rideNavigation.miniMapPosition != setting else { return }
        appSettings.rideNavigation.miniMapPosition = setting
        persistSettings()
        renderMiniViewState()
    }

    public func setMiniMapScale(_ scale: Double) {
        let setting = MiniMapScale(scale)
        guard appSettings.rideNavigation.miniMapScale != setting else { return }
        appSettings.rideNavigation.miniMapScale = setting
        persistSettings()
        renderMiniViewState()
    }

    public func toggleMiniMapLayoutOrientation() {
        appSettings.rideNavigation.miniMapLayoutOrientation =
            appSettings.rideNavigation.miniMapLayoutOrientation == .portrait ? .landscape : .portrait
        persistSettings()
        renderMiniViewState()
    }
}
