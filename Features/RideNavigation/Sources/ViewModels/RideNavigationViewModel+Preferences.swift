import Foundation
import RideNavigationDomain
import SettingsDomain

@MainActor
extension RideNavigationViewModel {
    public func showHome() {
        guard !hasActiveSession else { return }
        routeTask?.cancel()
        routeTask = nil
        screen = .home
        selectedRoute = nil
        trailMap.reset()
        roadRoute = nil
        roadRoutes = []
        roadNavigationPurpose = nil
        trailExitPreview = nil
        selectedRoadRouteIndex = 0
        resetRoadStepGuidance()
        selectedDestination = nil
        mapDisplayStyle = .map
        isRerouting = false
        isCalculatingRoadRoutes = false
        errorText = nil
        render()
    }

    public func setMapStyle(_ styleID: String) {
        switch styleID {
        case Constants.focusMapStyleID where allowsFocusMapStyle:
            mapDisplayStyle = .focus
            appSettings.rideNavigation.preferredMapStyle = .focus
        case MapSourceDescriptor.appleStandard.id:
            mapSource = .appleStandard
            mapDisplayStyle = .map
            if allowsFocusMapStyle {
                appSettings.rideNavigation.preferredMapStyle = .standard
            }
        case MapSourceDescriptor.appleHybrid.id:
            mapSource = .appleHybrid
            mapDisplayStyle = .map
            if allowsFocusMapStyle {
                appSettings.rideNavigation.preferredMapStyle = .satellite
            }
        default:
            return
        }
        if allowsFocusMapStyle {
            persistSettings()
        }
        render()
    }

    public func setAvoidsTolls(_ avoidsTolls: Bool) {
        guard appSettings.rideNavigation.avoidsTolls != avoidsTolls else { return }
        appSettings.rideNavigation.avoidsTolls = avoidsTolls
        routePreferencesDidChange()
    }

    public func setAvoidsHighways(_ avoidsHighways: Bool) {
        guard appSettings.rideNavigation.avoidsHighways != avoidsHighways else { return }
        appSettings.rideNavigation.avoidsHighways = avoidsHighways
        routePreferencesDidChange()
    }

    public func toggleVoice() {
        isVoiceMuted.toggle()
        render()
    }

    public func setMapHeadingUp(_ isHeadingUp: Bool) {
        let orientation: RideNavigationMapOrientationPreference = isHeadingUp ? .headingUp : .northUp
        guard appSettings.rideNavigation.mapOrientation != orientation else { return }
        appSettings.rideNavigation.mapOrientation = orientation
        cameraMode = followCamera
        persistSettings()
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
        appSettings = settings
        switch settings.rideNavigation.preferredMapStyle {
        case .focus:
            break
        case .standard:
            mapSource = .appleStandard
        case .satellite:
            mapSource = .appleHybrid
        }
        render()
    }

    func routePreferencesDidChange() {
        persistSettings()
        guard activity == .preview,
              let destination = selectedDestination,
              let origin = locationSnapshot.coordinate else {
            render()
            return
        }
        recalculatePreviewRoutes(from: origin, to: destination)
    }

    func persistSettings() {
        let previousTask = settingsSaveTask
        previousTask?.cancel()
        let settings = appSettings
        let saveSettings = saveSettings
        settingsSaveTask = Task {
            await previousTask?.value
            guard !Task.isCancelled else { return }
            await saveSettings.execute(settings)
        }
    }

    var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func resetRoadStepGuidance() {
        activeRoadStepIndex = .zero
        announcedRoadStepIndex = nil
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
