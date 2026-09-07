import Foundation
import RideNavigationDomain
import SettingsDomain

@MainActor
extension RideNavigationViewModel {
    public func showHome() {
        guard !hasActiveSession else { return }
        planningController.resetPlan()
        screen = .home
        library.resetPersistence()
        activityController.resetForPreview()
        activityController.resetRoadStepGuidance()
        mapDisplayStyle = .map
        errorText = nil
        library.clearError()
        render()
    }

    public func setMapStyle(_ styleID: String) {
        let style: RideNavigationMapStylePreference
        switch styleID {
        case Constants.focusMapStyleID where allowsFocusMapStyle: style = .focus
        case MapSourceDescriptor.appleStandard.id: style = .standard
        case MapSourceDescriptor.appleHybrid.id: style = .satellite
        default: return
        }
        if allowsFocusMapStyle {
            guard persistSettings(.preferredMapStyle(style)) else { return }
            applyPreferredMapStyleForActiveNavigation()
        } else {
            mapSource = style == .satellite ? .appleHybrid : .appleStandard
            mapDisplayStyle = .map
        }
        render()
    }

    public func setAvoidsTolls(_ avoidsTolls: Bool) {
        guard appSettings.rideNavigation.avoidsTolls != avoidsTolls else { return }
        guard persistSettings(.avoidsTolls(avoidsTolls)) else { return }
        routePreferencesDidChange()
    }

    public func setAvoidsHighways(_ avoidsHighways: Bool) {
        guard appSettings.rideNavigation.avoidsHighways != avoidsHighways else { return }
        guard persistSettings(.avoidsHighways(avoidsHighways)) else { return }
        routePreferencesDidChange()
    }

    public func toggleVoice() {
        activityController.toggleVoice()
        render()
    }

    public func setMapHeadingUp(_ isHeadingUp: Bool) {
        let orientation: RideNavigationMapOrientationPreference = isHeadingUp ? .headingUp : .northUp
        guard appSettings.rideNavigation.mapOrientation != orientation else { return }
        guard persistSettings(.mapOrientation(orientation)) else { return }
        cameraMode = followCamera
        render()
    }

    public func handleMapIntent(_ intent: NavigationMapIntent) {
        switch intent {
        case .userMovedCamera:
            cameraMode = .userControlled
        case .recenter:
            cameraMode = followCamera
        case .overview:
            cameraMode = .overview(allVisibleCoordinates)
        case .selectMarker:
            break
        }
        render()
    }

    func receiveLoadedSettings(_ settings: AppSettings) {
        let routePreferencesChanged = appSettings.rideNavigation.avoidsTolls != settings.rideNavigation.avoidsTolls
            || appSettings.rideNavigation.avoidsHighways != settings.rideNavigation.avoidsHighways
        appSettings = settings
        activityController.updatePreferences(roadRoutePreferences)
        switch settings.rideNavigation.preferredMapStyle {
        case .focus:
            break
        case .standard:
            mapSource = .appleStandard
        case .satellite:
            mapSource = .appleHybrid
        }
        if allowsFocusMapStyle { applyPreferredMapStyleForActiveNavigation() }
        if case .follow = cameraMode { cameraMode = followCamera }
        if routePreferencesChanged {
            routePreferencesDidChange()
        } else {
            render()
        }
    }

    func routePreferencesDidChange() {
        guard activityController.snapshot.activity == .preview,
              let destination = planningController.snapshot.selectedDestination,
              let origin = locationSnapshot.coordinate else {
            render()
            return
        }
        recalculatePreviewRoutes(from: origin, to: destination)
    }

    func receiveSettingsSnapshot(_ snapshot: AppSettingsSnapshot) {
        pendingSettings.receive(snapshot)
        receiveLoadedSettings(pendingSettings.settings)
    }

    public func dismissSettingsSaveError() {
        settingsSaveError = nil
    }

    @discardableResult
    func persistSettings(_ change: AppSettingsChange.Navigation) -> Bool {
        do {
            try pendingSettings.enqueue(.navigation(change))
            appSettings = pendingSettings.settings
            guard settingsSaveTask == nil else { return true }
            settingsWorkerGeneration &+= 1
            let generation = settingsWorkerGeneration
            let update = dependencies.updateSettings
            settingsSaveTask = Task { [weak self] in
                defer {
                    if self?.settingsWorkerGeneration == generation { self?.settingsSaveTask = nil }
                }
                while !Task.isCancelled, let pending = self?.pendingSettings.next {
                    do {
                        let result = try await update.execute(expectedVIN: pending.expectedVIN, change: pending.change)
                        guard !Task.isCancelled, let self else { return }
                        pendingSettings.complete(id: pending.id, result: result)
                        receiveLoadedSettings(pendingSettings.settings)
                    } catch {
                        guard !Task.isCancelled, let self else { return }
                        if pendingSettings.reject(id: pending.id) {
                            settingsSaveError = String(localized: .rideNavigationSettingsSaveFailed)
                        }
                        receiveLoadedSettings(pendingSettings.settings)
                    }
                }
            }
            return true
        } catch {
            settingsSaveError = String(localized: .rideNavigationSettingsSaveFailed)
            return false
        }
    }

    func applyPreferredMapStyleForActiveNavigation() {
        switch appSettings.rideNavigation.preferredMapStyle {
        case .focus:
            mapDisplayStyle = .focus
        case .standard:
            mapSource = .appleStandard
            mapDisplayStyle = .map
        case .satellite:
            mapSource = .appleHybrid
            mapDisplayStyle = .map
        }
    }

}
extension MiniMapPosition {
    init(_ position: RideNavigationMiniViewState.Position) {
        self.init(
            horizontalFraction: position.horizontalFraction,
            verticalFraction: position.verticalFraction
        )
    }
}

extension RideNavigationMiniViewState.Position {
    init(_ position: MiniMapPosition) {
        self.init(
            horizontalFraction: position.horizontalFraction,
            verticalFraction: position.verticalFraction
        )
    }
}
