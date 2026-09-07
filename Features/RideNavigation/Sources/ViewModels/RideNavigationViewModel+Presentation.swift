import BikeDomain
import EnvironmentDomain
import Foundation
import RideNavigationDomain
import SettingsDomain
import VehicleSession

@MainActor
extension RideNavigationViewModel {
    func render() {
        if presentationMode == .mini {
            renderMiniViewState()
            return
        }
        let planning = planningController.snapshot
        let speed = presentedSpeed
        let altitude = presentedAltitude
        let trailGuidanceSnapshot = trailGuidance.snapshot
        viewState = RideNavigationViewState(
            screen: screen,
            activity: activity,
            mapScene: makeMapScene(),
            selectedMapStyleID: selectedMapStyleID,
            allowsFocusMapStyle: allowsFocusMapStyle,
            isHeadingUp: isHeadingUp,
            speedText: speed.0,
            speedUnit: speed.1,
            modeText: presentedModeText,
            batteryText: presentedBatteryText,
            elapsedText: elapsedText(at: now()), distanceText: currentDistanceText,
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
            roadRouteOptions: activity == .preview ? roadRouteOptions : [],
            avoidsTolls: appSettings.rideNavigation.avoidsTolls,
            avoidsHighways: appSettings.rideNavigation.avoidsHighways,
            showsRoadRoutePreferences: activity == .preview && planning.selectedDestination != nil,
            isCalculatingRoadRoutes: planning.isCalculatingRoadRoutes,
            isPreparingTrail: trailGuidanceSnapshot.isPreparing,
            isRerouting: planning.isRerouting,
            isSearching: planning.isSearching,
            errorText: errorText ?? planning.errorMessage ?? library.snapshot.errorMessage,
            isVoiceMuted: isVoiceMuted,
            canReverseRoute: planning.selectedRoute != nil && activity == .preview, canMinimize: canMinimize,
            canFindTrailExit: activity == .following && planning.selectedRoute != nil
                && planning.trailExitPreview == nil,
            canResumeGPX: activity == .navigating
                && planning.roadNavigationPurpose == .trailExit
                && planning.selectedRoute != nil,
            isFindingTrailExit: planning.isFindingTrailExit,
            trailExitPreview: presentedTrailExit,
            showsIncomingDestinationPrompt: showsIncomingDestinationPrompt,
            incomingDestinationTitle: planning.pendingExternalDestination?.name,
            trailEntryPrompt: trailGuidanceSnapshot.entryPrompt,
            arrivalPrompt: trailGuidanceSnapshot.arrivalPrompt,
            forkGuidance: presentedForkGuidance,
            routePersistence: library.snapshot.persistence.status,
            canSaveCompletedRoute: completedRecording != nil, canExportCompletedRoute: canExportCompletedRoute,
            summaryIsSuccessful: state.summaryIsSuccessful,
            completedRouteName: completedRecording?.name,
            summaryTitle: summaryTitle, summaryDetail: summaryDetail
        )
        renderMiniViewState()
    }

    private var presentedSpeed: (String, String) {
        mapper.speed(
            kilometersPerHour: vehicleSnapshot.resolvedSpeedKilometersPerHour
                ?? latestDeviceSpeedKilometersPerHour,
            measurementSystem: measurementSystem
        )
    }

    private var presentedAltitude: (String, String)? {
        mapper.altitude(
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
        return state.lastValidBatteryText ?? "--%"
    }

    private var presentedModeText: String {
        if vehicleSnapshot.isCanonicalTelemetryAvailable,
           vehicleSnapshot.telemetry.mode.displayIndex != nil {
            return resolvedModeText
        }
        return state.lastValidModeText ?? String(localized: .rideNavigationModeUnavailable)
    }

    private var presentedGPXProgress: String? {
        guard activity == .following, let trailProgress else { return nil }
        let totalDistance = trailProgress.distanceAlongRouteMeters
            + trailProgress.remainingDistanceMeters
        guard totalDistance > .zero else { return mapper.progress(1) }
        return mapper.progress(trailProgress.distanceAlongRouteMeters / totalDistance)
    }

    private var presentedConnectionNotice: String? {
        guard !vehicleSnapshot.isCanonicalTelemetryAvailable else { return nil }
        switch vehicleSnapshot.connection.state {
        case .scanning, .connecting, .discovering, .authenticating, .authenticated,
             .subscribed, .receivingTelemetry, .reconnecting:
            return state.lastValidBatteryText != nil || state.lastValidModeText != nil
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
                detail: mapper.routeDetail($0, measurementSystem: measurementSystem)
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
            mapper.trailExitPreview($0, measurementSystem: measurementSystem)
        }
    }

    var presentedForkGuidance: RideNavigationForkGuidance? {
        let guidance = trailGuidance.snapshot.guidance
        return mapper.forkGuidance(
            routeState: guidance?.routeState,
            decision: guidance?.decision,
            measurementSystem: measurementSystem
        )
    }

    func renderMiniViewState() {
        let scene = frozenMiniMapScene ?? makeMiniMapScene()
        let guidanceSnapshot = trailGuidance.snapshot
        let statusText: String?
        if let miniCompletionTitle {
            statusText = miniCompletionTitle
        } else if planningController.snapshot.isRerouting {
            statusText = String(localized: .rideNavigationRerouting)
        } else if guidanceSnapshot.arrivalPrompt != nil {
            statusText = String(localized: .rideNavigationEndReachedTap)
        } else if guidanceSnapshot.guidance?.routeState == .wrongFork {
            statusText = String(localized: .rideNavigationWrongFork)
        } else if activity == .following, didAnnounceOffRoute {
            statusText = String(localized: .rideNavigationOffTrail)
        } else if activity == .paused {
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

    func makeMiniMapScene() -> NavigationMapScene {
        mapSceneBuilder.makeMiniScene(
            from: makeMapScene(),
            camera: followCamera,
            rejoinGuide: rejoinGuide(inFocusModeOnly: false)
        )
    }

    func makeMapScene() -> NavigationMapScene {
        let guidanceSnapshot = trailGuidance.snapshot
        return mapSceneBuilder.makeScene(
            RideNavigationMapSceneBuilder.Input(
                source: mapSource,
                displayStyle: mapDisplayStyle,
                camera: cameraMode,
                userCoordinate: locationSnapshot.coordinate,
                userHeadingDegrees: locationSnapshot.courseDegrees,
                trailOverlay: RideNavigationMapPresentationMapper.TrailOverlayInput(
                hasSelectedRoute: planningController.snapshot.selectedRoute != nil,
                activity: activity,
                isPresentingTrailExit: planningController.snapshot.trailExitPreview != nil
                    || planningController.snapshot.roadNavigationPurpose == .trailExit,
                trailMap: trailMap.presentationSnapshot,
                guidancePlan: guidanceSnapshot.plan,
                guidance: guidanceSnapshot.guidance
                ),
                roadRoute: planningController.snapshot.roadRoute,
                roadRouteRevision: planningController.snapshot.roadRouteRevision,
                destination: planningController.snapshot.selectedDestination,
                trailExit: planningController.snapshot.trailExitPreview,
                trailExitRevision: planningController.snapshot.trailExitPreviewRevision,
                rejoinGuide: rejoinGuide(inFocusModeOnly: true),
                traces: routeTraces,
                lineAppearances: appSettings.rideNavigation.lineAppearances,
                showsCompassRing: appSettings.rideNavigation.showsCompassRing,
                showsRoadsInFocus: appSettings.rideNavigation.showsRoadsInFocus
            )
        )
    }

    private func rejoinGuide(inFocusModeOnly: Bool) -> [GeographicCoordinate]? {
        guard !inFocusModeOnly || mapDisplayStyle == .focus,
              activity == .following,
              didAnnounceOffRoute,
              let location = locationSnapshot.coordinate,
              let rejoinCoordinate = trailProgress?.rejoinCoordinate
        else { return nil }
        return [location, rejoinCoordinate]
    }

    private var routeTraces: [RideNavigationMapSceneBuilder.RouteTrace] {
        [
            .init(
                idPrefix: "recorded",
                role: .recorded,
                segments: recorder.snapshot(at: now()).route?.segments ?? []
            ),
            .init(
                idPrefix: "breadcrumb",
                role: .completed,
                segments: breadcrumbRecorder.snapshot(at: now()).route?.segments ?? []
            )
        ]
    }

    var roadRouteOptions: [RideNavigationRoadRouteOption] {
        planningController.snapshot.roadRoutes.enumerated().map { index, route in
            mapper.roadRouteOption(
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
        activity == .following || activity == .navigating
    }

    var selectedMapStyleID: String {
        mapDisplayStyle == .focus ? Constants.focusMapStyleID : mapSource.id
    }

    var roadRouteForExport: RideRoute? {
        planningController.snapshot.roadRoute?.exportRoute(
            name: planningController.snapshot.selectedDestination?.name
                ?? planningController.snapshot.roadRoute?.name ?? String(localized: .rideNavigationRouteName),
            createdAt: now()
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
