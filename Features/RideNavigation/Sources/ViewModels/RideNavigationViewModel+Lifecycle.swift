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
        startLibraryObservation(lifecycle: lifecycle)
        library.start()
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
            if pendingSettings.confirmed == nil { receiveLoadedSettings(settings) }
            startSettingsObservation(lifecycle: lifecycle)
        }
    }

    public func stop() {
        isStarted = false
        trailGuidance.cancelPreparation()
        library.stop()
        libraryObservationTask?.cancel()
        libraryObservationTask = nil
        operations.invalidateAll()
        settingsWorkerGeneration &+= 1
        pendingSettings.removeAll()
        appSettings = pendingSettings.settings
        isCalculatingRoadRoutes = false
        isRerouting = false
        isFindingTrailExit = false
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
