import EnvironmentDomain
import Foundation
import RideNavigationDomain
import SettingsDomain
import VehicleSession

@MainActor
extension RideNavigationViewModel {
    func render(isSearching: Bool? = nil) {
        if presentationMode == .mini {
            renderMiniViewState()
            return
        }
        let speed = presentedSpeed
        let mapScene = makeMapScene()
        let elapsed = elapsedText(at: now())
        let modeText = resolvedModeText
        let batteryText = vehicleSnapshot.telemetry.batteryLevel.percent.map { "\($0)%" } ?? "--%"
        let trailGuidanceSnapshot = trailGuidance.snapshot
        viewState = RideNavigationViewState(
            screen: screen,
            activity: activity,
            mapScene: mapScene,
            selectedMapStyleID: selectedMapStyleID,
            allowsFocusMapStyle: allowsFocusMapStyle,
            isHeadingUp: isHeadingUp,
            speedText: speed.0,
            speedUnit: speed.1,
            modeText: modeText,
            batteryText: batteryText,
            elapsedText: elapsed,
            distanceText: currentDistanceText,
            guidance: currentGuidance,
            routeTitle: selectedRoute?.name ?? selectedDestination?.name,
            savedRoutes: routeRows,
            searchQuery: searchQuery,
            searchResults: presentedSearchResults,
            roadRouteOptions: activity == .preview ? roadRouteOptions : [],
            avoidsTolls: appSettings.rideNavigation.avoidsTolls,
            avoidsHighways: appSettings.rideNavigation.avoidsHighways,
            showsRoadRoutePreferences: activity == .preview && selectedDestination != nil,
            isCalculatingRoadRoutes: isCalculatingRoadRoutes,
            isPreparingTrail: trailGuidanceSnapshot.isPreparing,
            isRerouting: isRerouting,
            isSearching: isSearching ?? viewState.isSearching,
            errorText: errorText,
            isVoiceMuted: isVoiceMuted,
            canReverseRoute: selectedRoute != nil && activity == .preview,
            canMinimize: canMinimize,
            canFindTrailExit: activity == .following && selectedRoute != nil && trailExitPreview == nil,
            canResumeGPX: activity == .navigating
                && roadNavigationPurpose == .trailExit
                && selectedRoute != nil,
            isFindingTrailExit: isFindingTrailExit,
            trailExitPreview: presentedTrailExit,
            showsIncomingDestinationPrompt: showsIncomingDestinationPrompt,
            incomingDestinationTitle: pendingExternalDestination?.name,
            trailEntryPrompt: trailGuidanceSnapshot.entryPrompt,
            arrivalPrompt: trailGuidanceSnapshot.arrivalPrompt,
            forkGuidance: presentedForkGuidance,
            routePersistence: state.routePersistence.status,
            canSaveCompletedRoute: completedRecording != nil,
            completedRouteName: completedRecording?.name,
            summaryTitle: summaryTitle,
            summaryDetail: summaryDetail
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

    var routeRows: [RideNavigationRouteRow] {
        savedRoutes.map {
            RideNavigationRouteRow(
                id: $0.id,
                title: $0.name,
                detail: mapper.routeDetail($0, measurementSystem: measurementSystem)
            )
        }
    }

    var presentedSearchResults: [RideNavigationSearchResult] {
        searchResults.map {
            RideNavigationSearchResult(id: $0.id, title: $0.name, detail: $0.detail)
        }
    }

    var presentedTrailExit: RideNavigationTrailExitPreview? {
        trailExitPreview.map {
            mapper.trailExitPreview($0, measurementSystem: measurementSystem)
        }
    }

    var presentedForkGuidance: RideNavigationForkGuidance? {
        let guidance = trailGuidance.snapshot.guidance
        if guidance?.routeState == .wrongFork {
            return RideNavigationForkGuidance(
                instructionText: "WRONG FORK",
                distanceText: "Return to the highlighted track",
                systemImage: "arrow.uturn.backward",
                emphasis: .warning
            )
        }
        guard let decision = guidance?.decision else { return nil }
        let instruction: String
        let systemImage: String
        switch decision.direction {
        case .left:
            instruction = "KEEP LEFT"
            systemImage = "arrow.turn.up.left"
        case .right:
            instruction = "KEEP RIGHT"
            systemImage = "arrow.turn.up.right"
        case .straight:
            instruction = "CONTINUE STRAIGHT"
            systemImage = "arrow.up"
        }
        return RideNavigationForkGuidance(
            instructionText: instruction,
            distanceText: mapper.distance(
                meters: decision.distanceMeters,
                measurementSystem: measurementSystem
            ),
            systemImage: systemImage
        )
    }

    func renderMiniViewState() {
        let scene = frozenMiniMapScene ?? makeMiniMapScene()
        let guidanceSnapshot = trailGuidance.snapshot
        let statusText: String?
        if let miniCompletionTitle {
            statusText = miniCompletionTitle
        } else if isRerouting {
            statusText = "REROUTING"
        } else if guidanceSnapshot.arrivalPrompt != nil {
            statusText = "END REACHED · TAP"
        } else if guidanceSnapshot.guidance?.routeState == .wrongFork {
            statusText = "WRONG FORK"
        } else if activity == .following, didAnnounceOffRoute {
            statusText = "OFF TRAIL"
        } else if activity == .paused {
            statusText = "RECORDING PAUSED"
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
            accessibilityLabel: statusText.map { "Mini navigation map, \($0)" }
                ?? "Mini navigation map"
        )
    }

    func makeMiniMapScene() -> NavigationMapScene {
        var scene = makeMapScene()
        var polylines = scene.polylines
        if activity == .following,
           didAnnounceOffRoute,
           !polylines.contains(where: { $0.role == .rejoinGuide }),
           let location = locationSnapshot.coordinate,
           let rejoinCoordinate = trailProgress?.rejoinCoordinate {
            polylines.append(
                .init(
                    id: "trail-rejoin-guide",
                    points: mapMapper.coordinates([location, rejoinCoordinate]),
                    role: .rejoinGuide
                )
            )
        }
        scene = NavigationMapScene(
            source: scene.source,
            displayStyle: scene.displayStyle,
            camera: followCamera,
            userCoordinate: scene.userCoordinate,
            userHeadingDegrees: scene.userHeadingDegrees,
            polylines: polylines,
            markers: [],
            directionalIndicators: scene.directionalIndicators
        )
        return scene
    }

    func makeMapScene() -> NavigationMapScene {
        var polylines: [NavigationMapPolyline] = []
        var markers: [NavigationMapMarker] = []
        var directionalIndicators: [NavigationMapDirectionalIndicator] = []
        appendSelectedRoute(to: &polylines, markers: &markers)
        appendDirectionalIndicators(to: &directionalIndicators)
        appendRoadRoutes(to: &polylines, markers: &markers)
        appendRejoinGuide(to: &polylines)
        appendRecordedRoutes(to: &polylines)
        return NavigationMapScene(
            source: mapSource,
            displayStyle: mapDisplayStyle,
            camera: cameraMode,
            userCoordinate: locationSnapshot.coordinate.map(mapMapper.coordinate),
            userHeadingDegrees: locationSnapshot.courseDegrees,
            polylines: polylines,
            markers: markers,
            directionalIndicators: directionalIndicators
        )
    }

    func appendRoadRoutes(
        to polylines: inout [NavigationMapPolyline],
        markers: inout [NavigationMapMarker]
    ) {
        if let roadRoute {
            polylines.append(
                .init(
                    id: "road-route",
                    points: mapMapper.coordinates(roadRoute.points),
                    role: .approach,
                    revision: state.roadRouteRevision
                )
            )
            if let selectedDestination {
                markers.append(
                    .init(
                        id: "destination",
                        coordinate: mapMapper.coordinate(selectedDestination.coordinate),
                        title: selectedDestination.name,
                        role: .finish
                    )
                )
            }
        }
        if let trailExitPreview {
            polylines.append(
                .init(
                    id: "trail-exit-preview",
                    points: mapMapper.coordinates(trailExitPreview.route.points),
                    role: .approach,
                    revision: state.trailExitPreviewRevision
                )
            )
            markers.append(
                .init(
                    id: "trail-exit-destination",
                    coordinate: mapMapper.coordinate(trailExitPreview.destination.coordinate),
                    title: trailExitPreview.destination.name,
                    role: .finish
                )
            )
        }
    }

    func appendRejoinGuide(to polylines: inout [NavigationMapPolyline]) {
        if mapDisplayStyle == .focus,
           activity == .following,
           didAnnounceOffRoute,
           let location = locationSnapshot.coordinate,
           let rejoinCoordinate = trailProgress?.rejoinCoordinate {
            polylines.append(
                .init(
                    id: "trail-rejoin-guide",
                    points: mapMapper.coordinates([location, rejoinCoordinate]),
                    role: .rejoinGuide
                )
            )
        }
    }

    func appendRecordedRoutes(to polylines: inout [NavigationMapPolyline]) {
        let recordingRoute = recorder.snapshot(at: now()).route
        for (index, segment) in (recordingRoute?.segments ?? []).enumerated() {
            polylines.append(
                .init(
                    id: "recorded-\(index)",
                    points: mapMapper.coordinates(segment.points.map(\.coordinate)),
                    role: .recorded,
                    revision: segment.points.count
                )
            )
        }
        let breadcrumbRoute = breadcrumbRecorder.snapshot(at: now()).route
        for (index, segment) in (breadcrumbRoute?.segments ?? []).enumerated() {
            polylines.append(
                .init(
                    id: "breadcrumb-\(index)",
                    points: mapMapper.coordinates(segment.points.map(\.coordinate)),
                    role: .completed,
                    revision: segment.points.count
                )
            )
        }
    }

    var roadRouteOptions: [RideNavigationRoadRouteOption] {
        roadRoutes.enumerated().map { index, route in
            mapper.roadRouteOption(
                route,
                index: index,
                isSelected: index == selectedRoadRouteIndex,
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
        roadRoute?.exportRoute(
            name: selectedDestination?.name ?? roadRoute?.name ?? "Route",
            createdAt: now()
        )
    }

    var measurementSystem: MeasurementSystem {
        vehicleSnapshot.settings.measurementSystem
    }

    var resolvedModeText: String {
        guard let displayIndex = vehicleSnapshot.telemetry.mode.displayIndex else { return "MODE --" }
        let mapIndex = displayIndex - 1
        let name: String?
        if let vin = vehicleSnapshot.profile?.vin {
            name = vehicleSnapshot.settings.powerModeNames(forVIN: vin)[mapIndex]?.value
        } else {
            name = nil
        }
        return name ?? "MODE \(displayIndex)"
    }

    enum Constants {
        static let offRouteDistanceMeters = 50.0
        static let routeRecoveryDistanceMeters = 30.0
        static let arrivalDistanceMeters = 30.0
        static let approachDistanceMeters = 100.0
        static let roadRerouteDistanceMeters = 75.0
        static let enduroLookAheadMeters = 35.0
        static let voiceDecisionDistanceMeters = 80.0
        static let minimumRerouteIntervalSeconds: TimeInterval = 15
        static let minimumSearchCharacters = 2
        static let searchDebounceMilliseconds = 300
        static let maximumSearchResults = 8
        static let maximumPreviewIndicators = 200
        static let previewMinimumIndicatorSpacingMeters = 40.0
        static let indicatorBearingLookAheadMeters = 5.0
        static let halfCircleDegrees = 180.0
        static let fullCircleDegrees = 360.0
        static let roadStepAdvanceDistanceMeters = 30.0
        static let roadStepDistanceAdvantageMeters = 10.0
        static let focusMapStyleID = "focus"
    }

}
