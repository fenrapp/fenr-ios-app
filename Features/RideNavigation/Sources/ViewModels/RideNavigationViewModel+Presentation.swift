import BikeDomain
import EnvironmentDomain
import Foundation
import RideNavigationDomain
import SettingsDomain
import VehicleSession

@MainActor
extension RideNavigationViewModel {
    func render() {
        if presentationMode != .mini {
            viewState = makeFullViewState(
                activity: activityController.snapshot, planning: planningController.snapshot,
                speed: presentedSpeed, altitude: presentedAltitude
            )
        }
        renderMiniViewState()
    }

    private func makeFullViewState(
        activity: RideNavigationActivitySnapshot,
        planning: RideNavigationPlanningSnapshot,
        speed: (String, String),
        altitude: (String, String)?
    ) -> RideNavigationViewState {
        .init(
            screen: screen,
            activity: activity.activity,
            mapScene: makeMapScene(activity: activity, planning: planning),
            selectedMapStyleID: selectedMapStyleID,
            allowsFocusMapStyle: allowsFocusMapStyle,
            isHeadingUp: isHeadingUp,
            speedText: speed.0,
            speedUnit: speed.1,
            modeText: presentedModeText,
            batteryText: presentedBatteryText,
            elapsedText: elapsedText(),
            distanceText: currentDistanceText,
            altitudeText: altitude?.0,
            altitudeUnit: altitude?.1 ?? "",
            gpxProgressText: presentedGPXProgress,
            connectionNoticeText: presentedConnectionNotice,
            showsGuidanceInFocus: appSettings.rideNavigation.showsGuidanceInFocus,
            guidance: currentGuidance,
            routeTitle: planning.selectedRoute?.name ?? planning.selectedDestination?.name,
            savedRoutes: routeRows,
            searchQuery: planning.searchQuery,
            searchResults: presentedSearchResults,
            roadRouteOptions: activity.activity == .preview ? roadRouteOptions : [],
            avoidsTolls: appSettings.rideNavigation.avoidsTolls,
            avoidsHighways: appSettings.rideNavigation.avoidsHighways,
            showsRoadRoutePreferences: activity.activity == .preview && planning.selectedDestination != nil,
            isCalculatingRoadRoutes: planning.isCalculatingRoadRoutes,
            isPreparingTrail: activity.trailGuidance.isPreparing,
            isRerouting: planning.isRerouting,
            isSearching: planning.isSearching,
            errorText: errorText ?? activity.errorMessage ?? planning.errorMessage ?? library.snapshot.errorMessage,
            isVoiceMuted: activity.isVoiceMuted,
            canReverseRoute: planning.selectedRoute != nil && activity.activity == .preview,
            canMinimize: canMinimize,
            canFindTrailExit: canFindTrailExit(activity: activity, planning: planning),
            canResumeGPX: canResumeGPX(activity: activity, planning: planning),
            isFindingTrailExit: planning.isFindingTrailExit,
            trailExitPreview: presentedTrailExit,
            showsIncomingDestinationPrompt: showsIncomingDestinationPrompt,
            incomingDestinationTitle: planning.pendingExternalDestination?.name,
            trailEntryPrompt: activity.trailGuidance.entryPrompt,
            arrivalPrompt: activity.trailGuidance.arrivalPrompt,
            forkGuidance: presentedForkGuidance,
            routePersistence: library.snapshot.persistence.status,
            canSaveCompletedRoute: activity.completedRecording != nil,
            canExportCompletedRoute: canExportCompletedRoute,
            summaryIsSuccessful: activity.completion?.isSuccessful ?? true,
            completedRouteName: activity.completedRecording?.name,
            summaryTitle: summaryTitle,
            summaryDetail: summaryDetail
        )
    }

    private func canFindTrailExit(
        activity: RideNavigationActivitySnapshot, planning: RideNavigationPlanningSnapshot
    ) -> Bool {
        activity.activity == .following && planning.selectedRoute != nil && planning.trailExitPreview == nil
    }

    private func canResumeGPX(
        activity: RideNavigationActivitySnapshot, planning: RideNavigationPlanningSnapshot
    ) -> Bool {
        activity.activity == .navigating && planning.roadNavigationPurpose == .trailExit
            && planning.selectedRoute != nil
    }

    private var presentedSpeed: (String, String) {
        dependencies.presentationMapper.speed(
            kilometersPerHour: vehicleSnapshot.resolvedSpeedKilometersPerHour
                ?? latestDeviceSpeedKilometersPerHour,
            measurementSystem: measurementSystem
        )
    }

    private var presentedAltitude: (String, String)? {
        dependencies.presentationMapper.altitude(
            meters: locationSnapshot.altitudeMeters,
            verticalAccuracyMeters: locationSnapshot.verticalAccuracyMeters,
            measurementSystem: measurementSystem
        )
    }

    private var presentedBatteryText: String {
        if vehicleSnapshot.isCanonicalTelemetryAvailable,
           let percentage = vehicleSnapshot.telemetry.batteryLevel.percent {
            return "\(percentage)%"
        }
        return lastValidBatteryText ?? "--%"
    }

    private var presentedModeText: String {
        if vehicleSnapshot.isCanonicalTelemetryAvailable,
           vehicleSnapshot.telemetry.mode.displayIndex != nil {
            return resolvedModeText
        }
        return lastValidModeText ?? String(localized: .rideNavigationModeUnavailable)
    }

    private var presentedGPXProgress: String? {
        guard activityController.snapshot.activity == .following,
              let trailProgress = activityController.snapshot.trailProgress else { return nil }
        let totalDistance = trailProgress.distanceAlongRouteMeters
            + trailProgress.remainingDistanceMeters
        guard totalDistance > .zero else { return dependencies.presentationMapper.progress(1) }
        return dependencies.presentationMapper.progress(trailProgress.distanceAlongRouteMeters / totalDistance)
    }

    private var presentedConnectionNotice: String? {
        guard !vehicleSnapshot.isCanonicalTelemetryAvailable else { return nil }
        switch vehicleSnapshot.connection.state {
        case .scanning, .connecting, .discovering, .authenticating, .authenticated,
             .subscribed, .receivingTelemetry, .reconnecting:
            return lastValidBatteryText != nil || lastValidModeText != nil
                ? String(localized: .rideNavigationBikeReconnecting)
                : nil
        case .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff,
             .pairingResetRequired, .disconnected, .failed:
            return String(localized: .rideNavigationBikeDisconnected)
        case .idle:
            return nil
        }
    }

    var routeRows: [RideNavigationRouteRow] {
        library.snapshot.savedRoutes.map {
            RideNavigationRouteRow(
                id: $0.id,
                title: $0.name,
                detail: dependencies.presentationMapper.routeDetail($0, measurementSystem: measurementSystem)
            )
        }
    }

    var presentedSearchResults: [RideNavigationSearchResult] {
        planningController.snapshot.searchResults.map {
            RideNavigationSearchResult(id: $0.id, title: $0.name, detail: $0.detail)
        }
    }

    var presentedTrailExit: RideNavigationTrailExitPreview? {
        planningController.snapshot.trailExitPreview.map {
            dependencies.presentationMapper.trailExitPreview($0, measurementSystem: measurementSystem)
        }
    }

    var presentedForkGuidance: RideNavigationForkGuidance? {
        let guidance = activityController.snapshot.trailGuidance.guidance
        return dependencies.presentationMapper.forkGuidance(
            routeState: guidance?.routeState,
            decision: guidance?.decision,
            measurementSystem: measurementSystem
        )
    }

    func renderMiniViewState() {
        let scene = frozenMiniMapScene ?? makeMiniMapScene()
        let guidanceSnapshot = activityController.snapshot.trailGuidance
        let statusText: String?
        if let miniCompletionTitle {
            statusText = miniCompletionTitle
        } else if planningController.snapshot.isRerouting {
            statusText = String(localized: .rideNavigationRerouting)
        } else if guidanceSnapshot.arrivalPrompt != nil {
            statusText = String(localized: .rideNavigationEndReachedTap)
        } else if guidanceSnapshot.guidance?.routeState == .wrongFork {
            statusText = String(localized: .rideNavigationWrongFork)
        } else if activityController.snapshot.activity == .following, activityController.snapshot.didAnnounceOffRoute {
            statusText = String(localized: .rideNavigationOffTrail)
        } else if activityController.snapshot.activity == .paused {
            statusText = String(localized: .rideNavigationRecordingPaused)
        } else {
            statusText = nil
        }
        miniViewState = RideNavigationMiniViewState(
            mapScene: scene,
            position: RideNavigationMiniViewState.Position(appSettings.rideNavigation.miniMapPosition),
            scale: appSettings.rideNavigation.miniMapScale.value,
            scaleRange: MiniMapScale.minimumValue ... MiniMapScale.maximumValue,
            isLandscape: appSettings.rideNavigation.miniMapLayoutOrientation == .landscape,
            statusText: statusText,
            forkGuidance: presentedForkGuidance,
            isArrivalPending: guidanceSnapshot.arrivalPrompt != nil,
            accessibilityLabel: statusText.map {
                String(localized: .rideNavigationMiniMapStatusAccessibility($0))
            } ?? String(localized: .rideNavigationMiniMapAccessibility)
        )
    }

    var roadRouteOptions: [RideNavigationRoadRouteOption] {
        planningController.snapshot.roadRoutes.enumerated().map { index, route in
            dependencies.presentationMapper.roadRouteOption(
                route,
                index: index,
                isSelected: index == planningController.snapshot.selectedRoadRouteIndex,
                measurementSystem: measurementSystem
            )
        }
    }

    var roadRoutePreferences: RoadRoutePreferences {
        RoadRoutePreferences(
            avoidsTolls: appSettings.rideNavigation.avoidsTolls,
            avoidsHighways: appSettings.rideNavigation.avoidsHighways
        )
    }

    var allowsFocusMapStyle: Bool {
        activityController.snapshot.activity == .following || activityController.snapshot.activity == .navigating
    }

    var selectedMapStyleID: String {
        mapDisplayStyle == .focus ? Constants.focusMapStyleID : mapSource.id
    }

    var roadRouteForExport: RideRoute? {
        planningController.snapshot.roadRoute?.exportRoute(
            name: planningController.snapshot.selectedDestination?.name
                ?? planningController.snapshot.roadRoute?.name ?? String(localized: .rideNavigationRouteName),
            createdAt: dependencies.timing.now()
        )
    }

    var measurementSystem: MeasurementSystem {
        vehicleSnapshot.settings.measurementSystem
    }

    var resolvedModeText: String {
        guard let displayIndex = vehicleSnapshot.telemetry.mode.displayIndex else {
            return String(localized: .rideNavigationModeUnavailable)
        }
        let mapIndex = displayIndex - 1
        let name: String?
        if let vin = vehicleSnapshot.profile?.vin {
            name = vehicleSnapshot.settings.powerModeNames(forVIN: vin)[mapIndex]?.value
        } else {
            name = nil
        }
        return name ?? String(localized: .rideNavigationModeNumber(displayIndex))
    }

    enum Constants {
        static let offRouteDistanceMeters = 50.0
        static let arrivalDistanceMeters = 30.0
        static let roadRerouteDistanceMeters = 75.0
        static let enduroLookAheadMeters = 35.0
        static let voiceDecisionDistanceMeters = 80.0
        static let roadStepAdvanceDistanceMeters = 30.0
        static let roadStepDistanceAdvantageMeters = 10.0
        static let focusMapStyleID = "focus"
    }

}
