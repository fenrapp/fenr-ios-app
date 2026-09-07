import Foundation
import SettingsDomain

@MainActor
extension RideNavigationViewModel {
    public var hasActiveSession: Bool {
        activityController.snapshot.hasActiveSession
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        lifecycleGeneration &+= 1
        let lifecycle = lifecycleGeneration
        startLibraryObservation(lifecycle: lifecycle)
        startPlanningObservation(lifecycle: lifecycle)
        startActivityObservation(lifecycle: lifecycle)
        library.start()
        planningController.start()
        activityController.start()
        synchronizePresentationObservations()
        settingsLoadingGeneration &+= 1
        let settingsGeneration = settingsLoadingGeneration
        let loadSettings = dependencies.loadSettings
        settingsLoadingTask = Task { [weak self] in
            let settings = await loadSettings.execute()
            guard !Task.isCancelled else { return }
            guard let self,
                  settingsLoadingGeneration == settingsGeneration, lifecycleGeneration == lifecycle,
                  isStarted else { return }
            if pendingSettings.confirmed == nil { receiveLoadedSettings(settings) }
            startSettingsObservation(lifecycle: lifecycle)
        }
    }

    public func stop() {
        isStarted = false
        lifecycleGeneration &+= 1
        activityController.stop()
        activityObservationTask?.cancel()
        activityObservationTask = nil
        planningController.stop()
        planningObservationTask?.cancel()
        planningObservationTask = nil
        library.stop()
        libraryObservationTask?.cancel()
        libraryObservationTask = nil
        stopVehicleObservation()
        stopLocationObservation()
        settingsLoadingGeneration &+= 1
        settingsLoadingTask?.cancel()
        settingsLoadingTask = nil
        settingsObservationGeneration &+= 1
        settingsObservationTask?.cancel()
        settingsObservationTask = nil
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        settingsWorkerGeneration &+= 1
        pendingSettings.removeAll()
        appSettings = pendingSettings.settings
        if viewState.isSearching {
            render()
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
        screen == .map && hasActiveSession
    }

    public func setMiniMapPosition(_ position: RideNavigationMiniViewState.Position) {
        let setting = MiniMapPosition(position)
        guard appSettings.rideNavigation.miniMapPosition != setting else { return }
        persistSettings(.miniMapPosition(setting))
        renderMiniViewState()
    }

    public func setMiniMapScale(_ scale: Double) {
        let setting = MiniMapScale(scale)
        guard appSettings.rideNavigation.miniMapScale != setting else { return }
        persistSettings(.miniMapScale(setting))
        renderMiniViewState()
    }

    public func toggleMiniMapLayoutOrientation() {
        let orientation: MiniMapLayoutOrientation =
            appSettings.rideNavigation.miniMapLayoutOrientation == .portrait ? .landscape : .portrait
        persistSettings(.miniMapLayoutOrientation(orientation))
        renderMiniViewState()
    }
}
