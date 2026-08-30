import Combine
import EnvironmentDomain
import Foundation
import RideNavigationDomain
import SettingsDomain
import VehicleSession

// swiftlint:disable file_length
@MainActor
public final class RideNavigationViewModel: ObservableObject {
    @Published public private(set) var viewState = RideNavigationViewState()
    @Published public private(set) var miniViewState = RideNavigationMiniViewState()
    @Published public private(set) var exportRequest: GPXExportRequest?
    @Published public private(set) var shareRequest: GPXExportRequest?

    private let vehicleSession: any VehicleSessionService
    private let observeDeviceSpeed: ObserveDeviceSpeedUseCase
    private let repository: any RecordedRouteRepository
    private let importer: any GPXRouteImporting
    private let exporter: any GPXRouteExporting
    private let placeSearch: any PlaceSearching
    private let roadRouteCalculator: any RoadRouteCalculating
    private let externalMapLinkResolver: any ExternalMapLinkResolving
    private let trailExitFinder: any TrailExitFinding
    private let guidance: any NavigationGuidanceClient
    private let loadSettings: LoadAppSettingsUseCase
    private let saveSettings: SaveAppSettingsUseCase
    private let mapper: RideNavigationPresentationMapper
    private let now: @Sendable () -> Date
    private var observationTask: Task<Void, Never>?
    private var locationObservationTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var routeTask: Task<Void, Never>?
    private var externalLinkTask: Task<Void, Never>?
    private var trailExitTask: Task<Void, Never>?
    private var draftSaveTask: Task<Void, Never>?
    private var loadingTask: Task<Void, Never>?
    private var settingsLoadingTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var routeSaveTask: Task<Void, Never>?
    private var routeDeletionTasks: [UUID: Task<Void, Never>] = [:]
    private var draftPersistenceTask: Task<Void, Never>?
    private var guidanceTask: Task<Void, Never>?
    private var isStarted = false
    private var presentationMode = RideNavigationPresentationMode.fullScreen
    private var vehicleSnapshot = VehicleSessionSnapshot()
    private var locationSnapshot = RideNavigationLocationSnapshot()
    private var latestDeviceSpeedKilometersPerHour: Double?
    private var frozenMiniMapScene: NavigationMapScene?
    private var miniCompletionTitle: String?
    private var savedRoutes: [RideRoute] = []
    private var searchResults: [NavigationPlace] = []
    private var selectedRoute: RideRoute?
    private var selectedDirection = RideRouteDirection.forward
    private var roadRoute: RoadNavigationRoute?
    private var roadRoutes: [RoadNavigationRoute] = []
    private var selectedRoadRouteIndex = 0
    private var activeRoadStepIndex = 0
    private var announcedRoadStepIndex: Int?
    private var selectedDestination: NavigationPlace?
    private var roadNavigationPurpose: RoadNavigationPurpose?
    private var trailExitPreview: TrailExitRoute?
    private var pendingExternalDestination: NavigationPlace?
    private var showsIncomingDestinationPrompt = false
    private var openIncomingDestinationAfterSummary = false
    private var recorder: RideRouteRecorder
    private var breadcrumbRecorder: RideRouteRecorder
    private var completedRecording: RideRoute?
    private var trailProgress: RideRouteProgress?
    private var activityStartedAt: Date?
    private var mapSource = MapSourceDescriptor.appleStandard
    private var mapDisplayStyle = NavigationMapDisplayStyle.map
    private var cameraMode = NavigationMapCamera.automatic
    private var searchQuery = ""
    private var errorText: String?
    private var isVoiceMuted = false
    private var isCalculatingRoadRoutes = false
    private var isRerouting = false
    private var isFindingTrailExit = false
    private var didAnnounceOffRoute = false
    private var lastRoadRerouteAt: Date?
    private var summaryTitle = "Ride complete"
    private var summaryDetail = ""
    private var appSettings = AppSettings()
    private var screen = RideNavigationViewState.Screen.home
    private var activity = RideNavigationViewState.Activity.preview

    public init(
        vehicleSession: any VehicleSessionService,
        observeDeviceSpeed: ObserveDeviceSpeedUseCase,
        repository: any RecordedRouteRepository,
        importer: any GPXRouteImporting,
        exporter: any GPXRouteExporting,
        placeSearch: any PlaceSearching,
        roadRouteCalculator: any RoadRouteCalculating,
        externalMapLinkResolver: any ExternalMapLinkResolving,
        trailExitFinder: any TrailExitFinding,
        guidance: any NavigationGuidanceClient,
        loadSettings: LoadAppSettingsUseCase,
        saveSettings: SaveAppSettingsUseCase,
        mapper: RideNavigationPresentationMapper,
        recorder: RideRouteRecorder,
        breadcrumbRecorder: RideRouteRecorder,
        now: @escaping @Sendable () -> Date
    ) {
        self.vehicleSession = vehicleSession
        self.observeDeviceSpeed = observeDeviceSpeed
        self.repository = repository
        self.importer = importer
        self.exporter = exporter
        self.placeSearch = placeSearch
        self.roadRouteCalculator = roadRouteCalculator
        self.externalMapLinkResolver = externalMapLinkResolver
        self.trailExitFinder = trailExitFinder
        self.guidance = guidance
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.mapper = mapper
        self.recorder = recorder
        self.breadcrumbRecorder = breadcrumbRecorder
        self.now = now
    }

    deinit {
        observationTask?.cancel()
        clockTask?.cancel()
        searchTask?.cancel()
        routeTask?.cancel()
        externalLinkTask?.cancel()
        trailExitTask?.cancel()
        draftSaveTask?.cancel()
        loadingTask?.cancel()
        settingsLoadingTask?.cancel()
        settingsSaveTask?.cancel()
        routeSaveTask?.cancel()
        routeDeletionTasks.values.forEach { $0.cancel() }
        draftPersistenceTask?.cancel()
        guidanceTask?.cancel()
        locationObservationTask?.cancel()
    }

    public var hasActiveSession: Bool {
        [.following, .navigating, .recording, .paused].contains(activity)
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        startLocationObservation()
        synchronizePresentationObservations()
        loadingTask?.cancel()
        let repository = repository
        loadingTask = Task { [weak self] in
            let routes = await repository.loadRoutes()
            guard !Task.isCancelled else { return }
            self?.receiveLoadedRoutes(routes)
        }
        settingsLoadingTask?.cancel()
        let loadSettings = loadSettings
        settingsLoadingTask = Task { [weak self] in
            let settings = await loadSettings.execute()
            guard !Task.isCancelled else { return }
            self?.receiveLoadedSettings(settings)
        }
    }

    public func stop() {
        isStarted = false
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

@MainActor
extension RideNavigationViewModel {
    public func startRecording() {
        let date = now()
        recorder.start(at: date, name: defaultRouteName(at: date))
        completedRecording = nil
        activityStartedAt = date
        screen = .map
        activity = .recording
        mapDisplayStyle = .map
        cameraMode = followCamera
        startClock()
        render()
        announce("Recording started")
    }

    public func toggleRecordingPause() {
        let date = now()
        switch activity {
        case .recording:
            recorder.pause(at: date)
            activity = .paused
            scheduleDraftSave()
            announce("Recording paused")
        case .paused:
            recorder.resume(at: date)
            activity = .recording
            announce("Recording resumed")
        default:
            return
        }
        render()
    }

    public func finishActivity() {
        let reason: CompletionReason
        switch activity {
        case .recording, .paused:
            reason = .rideRecorded
        case .following:
            reason = .trailEnded
        case .navigating where roadNavigationPurpose == .trailExit:
            reason = .exitNavigationEnded
        case .navigating:
            reason = .navigationEnded
        case .preview:
            return
        }
        finishActivity(reason: reason)
    }

    private func finishActivity(reason: CompletionReason) {
        routeTask?.cancel()
        routeTask = nil
        trailExitTask?.cancel()
        trailExitTask = nil
        let date = now()
        let finishedActivity = activity
        let keepsMiniCompletion = presentationMode == .mini && reason.isAutomaticArrival
        if keepsMiniCompletion {
            frozenMiniMapScene = makeMiniMapScene()
            miniCompletionTitle = reason.title
        }
        if reason == .rideRecorded {
            completedRecording = recorder.finish(at: date)
            summaryDetail = completedRecording.map { route in
                let distance = mapper.distance(
                    meters: route.distanceMeters,
                    measurementSystem: measurementSystem
                )
                return "\(distance) · \(elapsedText(at: date))"
            } ?? "No valid GPS points were recorded."
            replaceDraftPersistenceTask { [repository] in try? await repository.saveDraft(nil) }
        } else {
            summaryDetail = "\(elapsedText(at: date)) · \(currentDistanceText)"
        }
        summaryTitle = reason.title
        if finishedActivity == .following || finishedActivity == .navigating {
            _ = breadcrumbRecorder.finish(at: date)
        }
        activityStartedAt = nil
        activity = .preview
        mapDisplayStyle = .map
        isRerouting = false
        isCalculatingRoadRoutes = false
        isFindingTrailExit = false
        screen = .summary
        stopClock()
        synchronizePresentationObservations()
        render()
        if keepsMiniCompletion {
            locationObservationTask?.cancel()
            locationObservationTask = nil
        }
        if reason.emitsSuccessFeedback {
            replaceGuidanceTask { [guidance] in await guidance.notifySuccess() }
        }
    }

    public func discardActivity() {
        let destinationToOpen = openIncomingDestinationAfterSummary ? pendingExternalDestination : nil
        recorder.reset()
        breadcrumbRecorder.reset()
        completedRecording = nil
        frozenMiniMapScene = nil
        miniCompletionTitle = nil
        trailProgress = nil
        didAnnounceOffRoute = false
        lastRoadRerouteAt = nil
        selectedRoute = nil
        roadRoute = nil
        roadRoutes = []
        roadNavigationPurpose = nil
        trailExitPreview = nil
        selectedRoadRouteIndex = 0
        resetRoadStepGuidance()
        selectedDestination = nil
        activityStartedAt = nil
        activity = .preview
        mapDisplayStyle = .map
        isRerouting = false
        isCalculatingRoadRoutes = false
        isFindingTrailExit = false
        screen = .home
        stopClock()
        synchronizePresentationObservations()
        replaceDraftPersistenceTask { [repository] in try? await repository.saveDraft(nil) }
        render()
        if let destinationToOpen {
            pendingExternalDestination = nil
            openIncomingDestinationAfterSummary = false
            previewExternalDestination(destinationToOpen)
        }
    }

    public func saveCompletedRoute(name: String) {
        guard let completedRecording else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = completedRecording.renamed(
            trimmed.isEmpty ? completedRecording.name : trimmed,
            at: now()
        )
        let replacedRoute = savedRoutes.first { $0.id == route.id }
        publishSavedRoute(route)
        routeSaveTask?.cancel()
        let repository = repository
        routeSaveTask = Task { [weak self] in
            do {
                try await repository.save(route)
                try Task.checkCancellation()
                let routes = await repository.loadRoutes()
                try Task.checkCancellation()
                guard let self else { return }
                savedRoutes = routes
                if screen == .summary, self.completedRecording?.id == route.id {
                    self.completedRecording = route
                    errorText = nil
                }
                render()
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                savedRoutes.removeAll { $0.id == route.id }
                if let replacedRoute {
                    savedRoutes.insert(replacedRoute, at: .zero)
                }
                errorText = "The route could not be saved."
                render()
            }
        }
    }

    public func saveCompletedRouteAndClose(name: String) {
        guard completedRecording != nil else {
            discardActivity()
            return
        }
        saveCompletedRoute(name: name)
        discardActivity()
    }

    private func publishSavedRoute(_ route: RideRoute) {
        savedRoutes.removeAll { $0.id == route.id }
        savedRoutes.insert(route, at: .zero)
        completedRecording = route
        errorText = nil
        render()
    }

    public func exportCompletedRoute() {
        guard let route = completedRecording ?? selectedRoute ?? roadRouteForExport else {
            errorText = "There is no route available to export."
            render()
            return
        }
        do {
            exportRequest = GPXExportRequest(
                filename: sanitizedFilename(route.name) + ".gpx",
                data: try exporter.export(route)
            )
        } catch {
            errorText = "The GPX file could not be created."
            render()
        }
    }

    public func clearExportRequest() {
        exportRequest = nil
    }

    public func shareSavedRoute(id: UUID) {
        guard let route = savedRoutes.first(where: { $0.id == id }) else { return }
        do {
            shareRequest = GPXExportRequest(
                filename: sanitizedFilename(route.name) + ".gpx",
                data: try exporter.export(route)
            )
            errorText = nil
            render()
        } catch {
            errorText = "The GPX file could not be created."
            render()
        }
    }

    public func clearShareRequest() {
        shareRequest = nil
    }

    public func deleteSavedRoute(id: UUID) {
        guard savedRoutes.contains(where: { $0.id == id }) else { return }
        savedRoutes.removeAll { $0.id == id }
        if selectedRoute?.id == id {
            selectedRoute = nil
        }
        errorText = nil
        render()

        let repository = repository
        routeDeletionTasks[id] = Task { [weak self] in
            do {
                try await repository.delete(id: id)
                try Task.checkCancellation()
                let routes = await repository.loadRoutes()
                try Task.checkCancellation()
                self?.receiveRouteDeletion(routes, id: id, errorText: nil)
            } catch is CancellationError {
                return
            } catch {
                let routes = await repository.loadRoutes()
                guard !Task.isCancelled else { return }
                self?.receiveRouteDeletion(
                    routes,
                    id: id,
                    errorText: "The route could not be deleted."
                )
            }
        }
    }

    public func openIncomingMapLink(_ url: URL) {
        externalLinkTask?.cancel()
        let resolver = externalMapLinkResolver
        externalLinkTask = Task { [weak self] in
            do {
                let destination = try await resolver.destination(from: url)
                try Task.checkCancellation()
                guard let self else { return }
                pendingExternalDestination = destination
                if hasActiveSession {
                    showsIncomingDestinationPrompt = true
                    render()
                } else {
                    pendingExternalDestination = nil
                    previewExternalDestination(destination)
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                errorText = "This map link does not contain a destination FENR can open."
                render()
            }
        }
    }

    public func keepRidingWithIncomingDestination() {
        showsIncomingDestinationPrompt = false
        openIncomingDestinationAfterSummary = true
        render()
    }

    public func endRideAndOpenIncomingDestination() {
        showsIncomingDestinationPrompt = false
        guard let destination = pendingExternalDestination else {
            render()
            return
        }
        if activity == .recording || activity == .paused {
            openIncomingDestinationAfterSummary = true
            finishActivity(reason: .rideRecorded)
            return
        }
        stopNavigationWithoutSummary()
        pendingExternalDestination = nil
        previewExternalDestination(destination)
    }

    public func importGPX(from url: URL) {
        let gainedAccess = url.startAccessingSecurityScopedResource()
        defer { if gainedAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let fallbackName = url.deletingPathExtension().lastPathComponent
            let routes = try importer.importRoutes(from: data, fallbackName: fallbackName)
            guard let route = routes.first else { return }
            selectedRoute = route
            selectedDirection = .forward
            trailProgress = nil
            roadRoute = nil
            roadRoutes = []
            roadNavigationPurpose = nil
            trailExitPreview = nil
            selectedRoadRouteIndex = 0
            resetRoadStepGuidance()
            screen = .map
            activity = .preview
            mapDisplayStyle = .map
            cameraMode = .overview(route.points.map(\.coordinate))
            errorText = routes.count > 1
                ? "This GPX contains \(routes.count) tracks. Showing the first track."
                : nil
            render()
        } catch {
            errorText = "This GPX file could not be read."
            render()
        }
    }

    public func openSavedRoute(id: UUID) {
        guard let route = savedRoutes.first(where: { $0.id == id }) else { return }
        selectedRoute = route
        selectedDirection = .forward
        trailProgress = nil
        roadRoute = nil
        roadRoutes = []
        roadNavigationPurpose = nil
        trailExitPreview = nil
        selectedRoadRouteIndex = 0
        resetRoadStepGuidance()
        screen = .map
        activity = .preview
        mapDisplayStyle = .map
        cameraMode = .overview(route.points.map(\.coordinate))
        errorText = nil
        render()
    }

    public func toggleRouteDirection() {
        guard let selectedRoute else { return }
        selectedDirection = selectedDirection == .forward ? .reverse : .forward
        trailProgress = nil
        let oriented = selectedDirection == .forward ? selectedRoute : selectedRoute.reversed
        cameraMode = .overview(oriented.points.map(\.coordinate))
        render()
    }

    public func startPreviewedRoute() {
        guard selectedRoute != nil || roadRoute != nil else { return }
        if let route = orientedRoute,
           let origin = locationSnapshot.coordinate,
           let start = route.points.first?.coordinate,
           RideRouteGeometry.distanceMeters(from: origin, to: start) > Constants.approachDistanceMeters {
            startApproachRoute(from: origin, to: start)
            return
        }
        let date = now()
        startBreadcrumb(at: date)
        activityStartedAt = date
        activity = roadRoute == nil ? .following : .navigating
        if activity == .navigating, roadNavigationPurpose == nil {
            roadNavigationPurpose = .destination
        }
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        screen = .map
        startClock()
        render()
        announce(activity == .following ? "Enduro navigation started" : "Road navigation started")
    }

    public func updateSearchQuery(_ value: String) {
        searchQuery = value
        searchTask?.cancel()
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        errorText = nil
        guard query.count >= Constants.minimumSearchCharacters else {
            searchResults = []
            render(isSearching: false)
            return
        }
        render(isSearching: true)
        startSearch(query, debounce: true)
    }

    public func search() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= Constants.minimumSearchCharacters else { return }
        searchTask?.cancel()
        render(isSearching: true)
        startSearch(query, debounce: false)
    }

    public func selectSearchResult(id: UUID) {
        guard let destination = searchResults.first(where: { $0.id == id }),
              let origin = locationSnapshot.coordinate else {
            errorText = "A current location is required to calculate this route."
            render()
            return
        }
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: true)
    }

    public func findTrailExit() {
        guard activity == .following,
              selectedRoute != nil,
              let origin = locationSnapshot.coordinate else {
            errorText = "A current location is required to find a road-accessible exit."
            render()
            return
        }
        trailExitTask?.cancel()
        isFindingTrailExit = true
        errorText = nil
        render()
        let trailExitFinder = trailExitFinder
        let preferences = roadRoutePreferences
        trailExitTask = Task { [weak self] in
            do {
                let result = try await trailExitFinder.findExit(from: origin, preferences: preferences)
                try Task.checkCancellation()
                guard let self, activity == .following else { return }
                trailExitPreview = result
                isFindingTrailExit = false
                cameraMode = .overview((orientedRoute?.points.map(\.coordinate) ?? []) + result.route.points)
                render()
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                isFindingTrailExit = false
                errorText = "No road-accessible exit could be found."
                render()
            }
        }
    }

    public func cancelTrailExitPreview() {
        trailExitTask?.cancel()
        trailExitPreview = nil
        isFindingTrailExit = false
        cameraMode = followCamera
        render()
    }

    public func startTrailExit() {
        guard activity == .following, let exit = trailExitPreview else { return }
        roadRoute = exit.route
        roadRoutes = [exit.route]
        selectedRoadRouteIndex = .zero
        selectedDestination = exit.destination
        roadNavigationPurpose = .trailExit
        trailExitPreview = nil
        resetRoadStepGuidance()
        activity = .navigating
        applyPreferredMapStyleForActiveNavigation()
        cameraMode = followCamera
        errorText = nil
        render()
        announce("Exit navigation started")
    }

    public func resumeGPX() {
        guard activity == .navigating,
              roadNavigationPurpose == .trailExit,
              selectedRoute != nil else { return }
        routeTask?.cancel()
        roadRoute = nil
        roadRoutes = []
        selectedDestination = nil
        roadNavigationPurpose = nil
        resetRoadStepGuidance()
        activity = .following
        trailProgress = nil
        didAnnounceOffRoute = false
        cameraMode = followCamera
        errorText = nil
        render()
        announce("Enduro navigation resumed")
    }

    private func calculateRoadPreview(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace,
        showsSearchLoading: Bool
    ) {
        roadRoutes = []
        selectedRoadRouteIndex = .zero
        routeTask?.cancel()
        isCalculatingRoadRoutes = true
        render(isSearching: showsSearchLoading)
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let calculatedRoutes = try await roadRouteCalculator.routes(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self else { return }
                guard let firstRoute = calculatedRoutes.first else {
                    throw RoadRouteCalculationError.routeUnavailable
                }
                roadRoutes = calculatedRoutes
                selectedRoadRouteIndex = .zero
                roadRoute = firstRoute
                roadNavigationPurpose = .destination
                trailExitPreview = nil
                resetRoadStepGuidance()
                selectedDestination = destination
                selectedRoute = nil
                trailProgress = nil
                screen = .map
                activity = .preview
                mapDisplayStyle = .map
                cameraMode = .overview(roadRoute?.points ?? [])
                errorText = nil
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                errorText = "Apple Maps could not calculate this route."
            }
            self?.isCalculatingRoadRoutes = false
            self?.render(isSearching: false)
        }
    }

    public func selectRoadRouteOption(_ index: Int) {
        guard roadRoutes.indices.contains(index) else { return }
        selectedRoadRouteIndex = index
        roadRoute = roadRoutes[index]
        resetRoadStepGuidance()
        cameraMode = .overview(roadRoutes[index].points)
        render()
    }
}

@MainActor
extension RideNavigationViewModel {
    public func showHome() {
        guard !hasActiveSession else { return }
        routeTask?.cancel()
        routeTask = nil
        screen = .home
        selectedRoute = nil
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

    private func startSearch(_ query: String, debounce: Bool) {
        let placeSearch = placeSearch
        let coordinate = locationSnapshot.coordinate
        searchTask = Task { [weak self] in
            do {
                if debounce {
                    try await Task.sleep(for: .milliseconds(Constants.searchDebounceMilliseconds))
                }
                try Task.checkCancellation()
                let places = try await placeSearch.search(query, near: coordinate)
                try Task.checkCancellation()
                self?.receiveSearchResults(places, query: query)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.receiveSearchFailure(query: query)
            }
        }
    }

    private func receiveSearchResults(_ places: [NavigationPlace], query: String) {
        guard query == normalizedSearchQuery else { return }
        searchResults = Array(places.prefix(Constants.maximumSearchResults))
        errorText = searchResults.isEmpty ? "No destinations found." : nil
        render(isSearching: false)
    }

    private func receiveSearchFailure(query: String) {
        guard query == normalizedSearchQuery else { return }
        errorText = "Search is unavailable. Check your connection."
        render(isSearching: false)
    }

    private func receiveLoadedRoutes(_ routes: [RideRoute]) {
        savedRoutes = routes
        render()
    }

    private func receiveRouteDeletion(
        _ routes: [RideRoute],
        id: UUID,
        errorText: String?
    ) {
        routeDeletionTasks[id] = nil
        let pendingDeletionIDs = Set(routeDeletionTasks.keys)
        savedRoutes = routes.filter { !pendingDeletionIDs.contains($0.id) }
        self.errorText = errorText
        render()
    }

    private func receiveLoadedSettings(_ settings: AppSettings) {
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

    private func routePreferencesDidChange() {
        persistSettings()
        guard activity == .preview,
              let destination = selectedDestination,
              let origin = locationSnapshot.coordinate else {
            render()
            return
        }
        recalculatePreviewRoutes(from: origin, to: destination)
    }

    private func recalculatePreviewRoutes(
        from origin: GeographicCoordinate,
        to destination: NavigationPlace
    ) {
        routeTask?.cancel()
        isCalculatingRoadRoutes = true
        errorText = nil
        render()
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let routes = try await roadRouteCalculator.routes(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self, let firstRoute = routes.first else {
                    throw RoadRouteCalculationError.routeUnavailable
                }
                roadRoutes = routes
                selectedRoadRouteIndex = .zero
                roadRoute = firstRoute
                resetRoadStepGuidance()
                cameraMode = .overview(firstRoute.points)
                errorText = nil
                isCalculatingRoadRoutes = false
                render()
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                isCalculatingRoadRoutes = false
                errorText = "Apple Maps could not update these route preferences."
                render()
            }
        }
    }

    private func persistSettings() {
        settingsSaveTask?.cancel()
        let settings = appSettings
        let saveSettings = saveSettings
        settingsSaveTask = Task {
            await saveSettings.execute(settings)
        }
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func receiveVehicleSnapshot(_ snapshot: VehicleSessionSnapshot) {
        vehicleSnapshot = snapshot
        render()
    }

    private func receiveLocation(_ sample: DeviceSpeedSample) {
        latestDeviceSpeedKilometersPerHour = sample.kilometersPerHour
        locationSnapshot = RideNavigationLocationSnapshot(
            coordinate: sample.coordinate,
            horizontalAccuracyMeters: sample.horizontalAccuracyMeters,
            courseDegrees: sample.courseDegrees,
            courseAccuracyDegrees: sample.courseAccuracyDegrees,
            altitudeMeters: sample.altitudeMeters,
            observedAt: sample.observedAt
        )
        processLocationUpdate()
    }

    private func processLocationUpdate() {
        if let point = routePoint(from: locationSnapshot) {
            if activity == .recording {
                recorder.append(point)
                scheduleDraftSave()
            } else if activity == .following || activity == .navigating {
                breadcrumbRecorder.append(point)
            }
        }
        updateGuidanceStatus()
        if case .follow = cameraMode {
            cameraMode = followCamera
        }
        render()
    }

    private func updateGuidanceStatus() {
        if activity == .navigating,
           let location = locationSnapshot.coordinate {
            updateRoadStepProgress(from: location)
        }
        if activity == .navigating,
           let location = locationSnapshot.coordinate,
           let roadRoute,
           let distance = RideRouteGeometry.closestDistanceMeters(
               from: location,
               to: roadRoute.points
           ),
           distance > Constants.roadRerouteDistanceMeters {
            rerouteRoadNavigation(from: location)
        }
        if activity == .navigating,
           let location = locationSnapshot.coordinate,
           let finish = roadRoute?.points.last,
           RideRouteGeometry.distanceMeters(from: location, to: finish) <= Constants.arrivalDistanceMeters {
            if roadNavigationPurpose == .trailApproach {
                roadRoute = nil
                roadRoutes = []
                selectedDestination = nil
                roadNavigationPurpose = nil
                activity = .following
                trailProgress = nil
                resetRoadStepGuidance()
                didAnnounceOffRoute = false
                announce("Trail reached. Enduro mode active")
            } else if roadNavigationPurpose == .trailExit {
                finishActivity(reason: .exitPointReached)
            } else {
                finishActivity(reason: .destinationReached)
            }
            return
        }
        guard activity == .following,
              let location = locationSnapshot.coordinate,
              let route = orientedRoute,
              let progress = RideRouteGeometry.progress(
                  from: location,
                  along: route,
                  lookAheadMeters: Constants.enduroLookAheadMeters,
                  minimumDistanceAlongMeters: trailProgress?.distanceAlongRouteMeters ?? .zero
              ) else { return }
        trailProgress = progress
        if progress.distanceFromRouteMeters > Constants.offRouteDistanceMeters,
           !didAnnounceOffRoute {
            didAnnounceOffRoute = true
            announce("You are off trail. Follow the arrow back to the track")
            replaceGuidanceTask { [guidance] in await guidance.notifyWarning() }
        } else if progress.distanceFromRouteMeters < Constants.routeRecoveryDistanceMeters {
            didAnnounceOffRoute = false
        }
        if progress.remainingDistanceMeters <= Constants.arrivalDistanceMeters {
            finishActivity(reason: .trailComplete)
        }
    }

    private func render(isSearching: Bool? = nil) {
        if presentationMode == .mini {
            renderMiniViewState()
            return
        }
        let speed = mapper.speed(
            kilometersPerHour: vehicleSnapshot.resolvedSpeedKilometersPerHour
                ?? latestDeviceSpeedKilometersPerHour,
            measurementSystem: measurementSystem
        )
        let mapScene = makeMapScene()
        let elapsed = elapsedText(at: now())
        let modeText = resolvedModeText
        let batteryText = vehicleSnapshot.telemetry.batteryLevel.percent.map { "\($0)%" } ?? "--%"
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
            canSaveCompletedRoute: completedRecording != nil,
            summaryTitle: summaryTitle,
            summaryDetail: summaryDetail
        )
        renderMiniViewState()
    }

    private var routeRows: [RideNavigationRouteRow] {
        savedRoutes.map {
            RideNavigationRouteRow(
                id: $0.id,
                title: $0.name,
                detail: mapper.routeDetail($0, measurementSystem: measurementSystem)
            )
        }
    }

    private var presentedSearchResults: [RideNavigationSearchResult] {
        searchResults.map {
            RideNavigationSearchResult(id: $0.id, title: $0.name, detail: $0.detail)
        }
    }

    private var presentedTrailExit: RideNavigationTrailExitPreview? {
        trailExitPreview.map {
            mapper.trailExitPreview($0, measurementSystem: measurementSystem)
        }
    }

    private func renderMiniViewState() {
        let scene = frozenMiniMapScene ?? makeMiniMapScene()
        let statusText: String?
        if let miniCompletionTitle {
            statusText = miniCompletionTitle
        } else if isRerouting {
            statusText = "REROUTING"
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
            accessibilityLabel: statusText.map { "Mini navigation map, \($0)" }
                ?? "Mini navigation map"
        )
    }

    private func makeMiniMapScene() -> NavigationMapScene {
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
                    points: [location, rejoinCoordinate],
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
            markers: []
        )
        return scene
    }

    private func makeMapScene() -> NavigationMapScene {
        var polylines: [NavigationMapPolyline] = []
        var markers: [NavigationMapMarker] = []
        appendSelectedRoute(to: &polylines, markers: &markers)
        appendRoadRoutes(to: &polylines, markers: &markers)
        appendRejoinGuide(to: &polylines)
        appendRecordedRoutes(to: &polylines)
        return NavigationMapScene(
            source: mapSource,
            displayStyle: mapDisplayStyle,
            camera: cameraMode,
            userCoordinate: locationSnapshot.coordinate,
            userHeadingDegrees: locationSnapshot.courseDegrees,
            polylines: polylines,
            markers: markers
        )
    }

    private func appendSelectedRoute(
        to polylines: inout [NavigationMapPolyline],
        markers: inout [NavigationMapMarker]
    ) {
        if let route = orientedRoute {
            let routeRole: NavigationMapPolylineRole = trailExitPreview != nil
                || roadNavigationPurpose == .trailExit ? .completed : .planned
            for (index, segment) in route.segments.enumerated() {
                polylines.append(
                    NavigationMapPolyline(
                        id: "planned-\(index)",
                        points: segment.points.map(\.coordinate),
                        role: routeRole
                    )
                )
            }
            if let start = route.points.first?.coordinate {
                markers.append(.init(id: "start", coordinate: start, title: "Start", role: .start))
            }
            if let finish = route.points.last?.coordinate {
                markers.append(.init(id: "finish", coordinate: finish, title: "Finish", role: .finish))
            }
        }
    }

    private func appendRoadRoutes(
        to polylines: inout [NavigationMapPolyline],
        markers: inout [NavigationMapMarker]
    ) {
        if let roadRoute {
            polylines.append(.init(id: "road-route", points: roadRoute.points, role: .approach))
            if let selectedDestination {
                markers.append(
                    .init(
                        id: "destination",
                        coordinate: selectedDestination.coordinate,
                        title: selectedDestination.name,
                        role: .finish
                    )
                )
            }
        }
        if let trailExitPreview {
            polylines.append(
                .init(id: "trail-exit-preview", points: trailExitPreview.route.points, role: .approach)
            )
            markers.append(
                .init(
                    id: "trail-exit-destination",
                    coordinate: trailExitPreview.destination.coordinate,
                    title: trailExitPreview.destination.name,
                    role: .finish
                )
            )
        }
    }

    private func appendRejoinGuide(to polylines: inout [NavigationMapPolyline]) {
        if mapDisplayStyle == .focus,
           activity == .following,
           didAnnounceOffRoute,
           let location = locationSnapshot.coordinate,
           let rejoinCoordinate = trailProgress?.rejoinCoordinate {
            polylines.append(
                .init(id: "trail-rejoin-guide", points: [location, rejoinCoordinate], role: .rejoinGuide)
            )
        }
    }

    private func appendRecordedRoutes(to polylines: inout [NavigationMapPolyline]) {
        let recordingRoute = recorder.snapshot(at: now()).route
        for (index, segment) in (recordingRoute?.segments ?? []).enumerated() {
            polylines.append(
                .init(id: "recorded-\(index)", points: segment.points.map(\.coordinate), role: .recorded)
            )
        }
        let breadcrumbRoute = breadcrumbRecorder.snapshot(at: now()).route
        for (index, segment) in (breadcrumbRoute?.segments ?? []).enumerated() {
            polylines.append(
                .init(
                    id: "breadcrumb-\(index)",
                    points: segment.points.map(\.coordinate),
                    role: .completed
                )
            )
        }
    }

    private var orientedRoute: RideRoute? {
        guard let selectedRoute else { return nil }
        return selectedDirection == .forward ? selectedRoute : selectedRoute.reversed
    }

    private var roadRouteOptions: [RideNavigationRoadRouteOption] {
        roadRoutes.enumerated().map { index, route in
            mapper.roadRouteOption(
                route,
                index: index,
                isSelected: index == selectedRoadRouteIndex,
                measurementSystem: measurementSystem
            )
        }
    }

    private var roadRoutePreferences: RoadRoutePreferences {
        RoadRoutePreferences(
            avoidsTolls: appSettings.rideNavigation.avoidsTolls,
            avoidsHighways: appSettings.rideNavigation.avoidsHighways
        )
    }

    private var allowsFocusMapStyle: Bool {
        activity == .following || activity == .navigating
    }

    private var selectedMapStyleID: String {
        mapDisplayStyle == .focus ? Constants.focusMapStyleID : mapSource.id
    }

    private var roadRouteForExport: RideRoute? {
        roadRoute?.exportRoute(
            name: selectedDestination?.name ?? roadRoute?.name ?? "Route",
            createdAt: now()
        )
    }

    private var measurementSystem: MeasurementSystem {
        vehicleSnapshot.settings.measurementSystem
    }

    private var resolvedModeText: String {
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

    private var currentGuidance: RideNavigationGuidance? {
        if activity == .following, let trailProgress {
            let remainingDistance = mapper.distance(
                meters: trailProgress.remainingDistanceMeters,
                measurementSystem: measurementSystem
            )
            let targetBearing = didAnnounceOffRoute
                ? RideRouteGeometry.bearingDegrees(
                    from: locationSnapshot.coordinate ?? trailProgress.rejoinCoordinate,
                    to: trailProgress.rejoinCoordinate
                )
                : trailProgress.targetBearingDegrees
            return RideNavigationGuidance(
                text: didAnnounceOffRoute ? "OFF TRAIL" : "ENDURO · FOLLOW THE ARROW",
                detail: didAnnounceOffRoute
                    ? offTrailDistanceText(trailProgress.distanceFromRouteMeters)
                    : "\(remainingDistance) remaining",
                systemImage: "location.north.fill",
                rotationDegrees: relativeBearingDegrees(targetBearing),
                emphasis: didAnnounceOffRoute ? .warning : .standard
            )
        }
        if activity == .following {
            return RideNavigationGuidance(
                text: "ENDURO · FOLLOW THE TRACK",
                detail: "Waiting for an accurate location",
                systemImage: "location.north.fill",
                emphasis: .standard
            )
        }
        if activity == .paused {
            return RideNavigationGuidance(
                text: "RECORDING PAUSED",
                systemImage: "pause.circle.fill",
                emphasis: .warning
            )
        }
        if activity == .navigating {
            let step = activeRoadStep
            let instruction = step?.instruction.isEmpty == false
                ? step?.instruction
                : "Continue toward the selected destination"
            let distance = step.flatMap(roadStepDistanceToManeuver).map {
                mapper.distance(meters: $0, measurementSystem: measurementSystem)
            }
            let rotation = step.flatMap(roadStepTargetBearing).map(relativeBearingDegrees) ?? .zero
            return RideNavigationGuidance(
                text: instruction ?? "ROAD NAVIGATION",
                detail: distance.map { "\($0) to next maneuver" },
                systemImage: "location.north.fill",
                rotationDegrees: rotation,
                emphasis: .standard
            )
        }
        return nil
    }

    private func offTrailDistanceText(_ distanceMeters: Double) -> String {
        "\(mapper.distance(meters: distanceMeters, measurementSystem: measurementSystem)) to trail"
    }

    private var currentDistanceText: String {
        let meters: Double
        if activity == .recording || activity == .paused {
            meters = recorder.snapshot(at: now()).route?.distanceMeters ?? .zero
        } else if let roadRoute {
            meters = roadRoute.distanceMeters
        } else {
            meters = orientedRoute?.distanceMeters ?? .zero
        }
        return mapper.distance(meters: meters, measurementSystem: measurementSystem)
    }

    private var followCamera: NavigationMapCamera {
        guard let coordinate = locationSnapshot.coordinate else { return .automatic }
        let heading = isHeadingUp ? locationSnapshot.courseDegrees : nil
        return .follow(coordinate: coordinate, headingDegrees: heading)
    }

    private var isHeadingUp: Bool {
        appSettings.rideNavigation.mapOrientation == .headingUp
    }

    private var allVisibleCoordinates: [GeographicCoordinate] {
        if let route = orientedRoute { return route.points.map(\.coordinate) }
        if let roadRoute { return roadRoute.points }
        return recorder.snapshot(at: now()).route?.points.map(\.coordinate) ?? []
    }

    private func elapsedText(at date: Date) -> String {
        if activity == .recording || activity == .paused {
            return mapper.elapsed(recorder.snapshot(at: date).activeElapsedSeconds)
        }
        guard let activityStartedAt else { return "00:00" }
        return mapper.elapsed(max(date.timeIntervalSince(activityStartedAt), .zero))
    }

    private func startClock() {
        guard presentationMode == .fullScreen, clockTask == nil else { return }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                self?.render()
            }
        }
    }

    private func stopClock() {
        clockTask?.cancel()
        clockTask = nil
    }

    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        guard let route = recorder.snapshot(at: now()).route else { return }
        let repository = repository
        draftSaveTask = Task {
            do {
                try await Task.sleep(for: .seconds(2))
                try Task.checkCancellation()
                try await repository.saveDraft(route)
            } catch {
                return
            }
        }
    }

    private func announce(_ text: String) {
        guard !isVoiceMuted else { return }
        replaceGuidanceTask { [guidance] in await guidance.announce(text) }
    }

    private func startBreadcrumb(at date: Date) {
        breadcrumbRecorder.reset()
        breadcrumbRecorder.start(at: date, name: "Navigation breadcrumb")
        trailProgress = nil
        didAnnounceOffRoute = false
        lastRoadRerouteAt = nil
        if let point = routePoint(from: locationSnapshot) {
            breadcrumbRecorder.append(point)
        }
    }

    private func applyPreferredMapStyleForActiveNavigation() {
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

    private func resetRoadStepGuidance() {
        activeRoadStepIndex = .zero
        announcedRoadStepIndex = nil
    }

    private var activeRoadStep: RoadNavigationStep? {
        guard let roadRoute, roadRoute.steps.indices.contains(activeRoadStepIndex) else { return nil }
        return roadRoute.steps[activeRoadStepIndex]
    }

    private func updateRoadStepProgress(from location: GeographicCoordinate) {
        guard let roadRoute, !roadRoute.steps.isEmpty else { return }
        activeRoadStepIndex = min(activeRoadStepIndex, roadRoute.steps.index(before: roadRoute.steps.endIndex))
        while roadRoute.steps.indices.contains(activeRoadStepIndex + 1) {
            let current = roadRoute.steps[activeRoadStepIndex]
            let next = roadRoute.steps[activeRoadStepIndex + 1]
            let distanceToCurrentEnd = current.points.last.map {
                RideRouteGeometry.distanceMeters(from: location, to: $0)
            } ?? .infinity
            let currentDistance = RideRouteGeometry.closestDistanceMeters(
                from: location,
                to: current.points
            ) ?? .infinity
            let nextDistance = RideRouteGeometry.closestDistanceMeters(
                from: location,
                to: next.points
            ) ?? .infinity
            let reachedManeuver = distanceToCurrentEnd <= Constants.roadStepAdvanceDistanceMeters
            let enteredNextStep = nextDistance <= Constants.roadStepAdvanceDistanceMeters
                && nextDistance + Constants.roadStepDistanceAdvantageMeters < currentDistance
            guard reachedManeuver || enteredNextStep else { break }
            activeRoadStepIndex += 1
        }
        guard announcedRoadStepIndex != activeRoadStepIndex,
              let instruction = activeRoadStep?.instruction,
              !instruction.isEmpty else { return }
        announcedRoadStepIndex = activeRoadStepIndex
        announce(instruction)
    }

    private func roadStepDistanceToManeuver(_ step: RoadNavigationStep) -> Double? {
        guard let location = locationSnapshot.coordinate,
              let end = step.points.last else { return nil }
        return RideRouteGeometry.distanceMeters(from: location, to: end)
    }

    private func roadStepTargetBearing(_ step: RoadNavigationStep) -> Double? {
        guard let location = locationSnapshot.coordinate,
              let target = step.points.last else { return nil }
        return RideRouteGeometry.bearingDegrees(from: location, to: target)
    }

    private func routePoint(from snapshot: RideNavigationLocationSnapshot) -> RideRoutePoint? {
        guard let coordinate = snapshot.coordinate,
              let observedAt = snapshot.observedAt else { return nil }
        return RideRoutePoint(
            coordinate: coordinate,
            elevationMeters: snapshot.altitudeMeters,
            timestamp: observedAt,
            horizontalAccuracyMeters: snapshot.horizontalAccuracyMeters
        )
    }

    private func relativeBearingDegrees(_ absoluteBearingDegrees: Double) -> Double {
        let courseDegrees = locationSnapshot.courseDegrees ?? .zero
        var delta = (absoluteBearingDegrees - courseDegrees)
            .truncatingRemainder(dividingBy: Constants.fullCircleDegrees)
        if delta > Constants.halfCircleDegrees {
            delta -= Constants.fullCircleDegrees
        } else if delta < -Constants.halfCircleDegrees {
            delta += Constants.fullCircleDegrees
        }
        return delta
    }

    private func startApproachRoute(
        from origin: GeographicCoordinate,
        to start: GeographicCoordinate
    ) {
        let destination = NavigationPlace(
            name: selectedDirection == .forward ? "Trail start" : "Trail finish",
            detail: "Road approach to the selected trail entry",
            coordinate: start
        )
        roadRoutes = []
        selectedRoadRouteIndex = .zero
        routeTask?.cancel()
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let calculatedRoute = try await roadRouteCalculator.route(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self else { return }
                roadRoute = calculatedRoute
                roadNavigationPurpose = .trailApproach
                resetRoadStepGuidance()
                selectedDestination = destination
                let date = now()
                startBreadcrumb(at: date)
                activityStartedAt = date
                activity = .navigating
                applyPreferredMapStyleForActiveNavigation()
                cameraMode = followCamera
                startClock()
                errorText = nil
                render()
                announce("Road navigation to the trail entry started")
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                errorText = "The approach route could not be calculated."
                render()
            }
        }
    }

    private func rerouteRoadNavigation(from origin: GeographicCoordinate) {
        let date = now()
        if let lastRoadRerouteAt,
           date.timeIntervalSince(lastRoadRerouteAt) < Constants.minimumRerouteIntervalSeconds {
            return
        }
        guard let destination = selectedDestination else { return }
        lastRoadRerouteAt = date
        routeTask?.cancel()
        isRerouting = true
        render()
        let roadRouteCalculator = roadRouteCalculator
        let preferences = roadRoutePreferences
        routeTask = Task { [weak self] in
            do {
                let calculatedRoute = try await roadRouteCalculator.route(
                    from: origin,
                    to: destination,
                    preferences: preferences
                )
                try Task.checkCancellation()
                guard let self else { return }
                roadRoute = calculatedRoute
                roadRoutes = [calculatedRoute]
                selectedRoadRouteIndex = .zero
                resetRoadStepGuidance()
                isRerouting = false
                errorText = nil
                render()
                announce("Route updated")
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                isRerouting = false
                errorText = "Rerouting is unavailable. Continue toward the highlighted route."
                render()
            }
        }
    }

    private func previewExternalDestination(_ destination: NavigationPlace) {
        guard let origin = locationSnapshot.coordinate else {
            pendingExternalDestination = destination
            errorText = "A current location is required to calculate this route."
            render()
            return
        }
        stopClock()
        screen = .map
        activity = .preview
        mapDisplayStyle = .map
        selectedRoute = nil
        trailProgress = nil
        trailExitPreview = nil
        roadNavigationPurpose = .destination
        selectedDestination = destination
        errorText = nil
        calculateRoadPreview(from: origin, to: destination, showsSearchLoading: false)
    }

    private func stopNavigationWithoutSummary() {
        routeTask?.cancel()
        trailExitTask?.cancel()
        if activity == .following || activity == .navigating {
            _ = breadcrumbRecorder.finish(at: now())
        }
        activityStartedAt = nil
        trailProgress = nil
        trailExitPreview = nil
        roadRoute = nil
        roadRoutes = []
        selectedDestination = nil
        roadNavigationPurpose = nil
        resetRoadStepGuidance()
        didAnnounceOffRoute = false
        lastRoadRerouteAt = nil
        isRerouting = false
        isFindingTrailExit = false
        stopClock()
    }

    private func replaceDraftPersistenceTask(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        draftPersistenceTask?.cancel()
        draftPersistenceTask = Task {
            await operation()
        }
    }

    private func replaceGuidanceTask(
        _ operation: @escaping @Sendable () async -> Void
    ) {
        guidanceTask?.cancel()
        guidanceTask = Task {
            await operation()
        }
    }

    private func startLocationObservation() {
        guard locationObservationTask == nil, miniCompletionTitle == nil else { return }
        let observeDeviceSpeed = observeDeviceSpeed
        locationObservationTask = Task { [weak self] in
            let stream = await observeDeviceSpeed.execute()
            for await sample in stream where !Task.isCancelled {
                self?.receiveLocation(sample)
            }
        }
    }

    private func startVehicleObservation() {
        guard observationTask == nil else { return }
        let vehicleSession = vehicleSession
        observationTask = Task { [weak self] in
            let stream = await vehicleSession.observe()
            for await snapshot in stream where !Task.isCancelled {
                self?.receiveVehicleSnapshot(snapshot)
            }
        }
    }

    private func synchronizePresentationObservations() {
        switch presentationMode {
        case .hidden:
            observationTask?.cancel()
            observationTask = nil
            locationObservationTask?.cancel()
            locationObservationTask = nil
            stopClock()
        case .fullScreen:
            guard screen != .summary else {
                observationTask?.cancel()
                observationTask = nil
                locationObservationTask?.cancel()
                locationObservationTask = nil
                stopClock()
                return
            }
            startLocationObservation()
            startVehicleObservation()
            if hasActiveSession {
                startClock()
            }
        case .mini:
            observationTask?.cancel()
            observationTask = nil
            stopClock()
            startLocationObservation()
        }
    }

    private func defaultRouteName(at date: Date) -> String {
        "Ride \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let filename = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return filename.isEmpty ? "Ride" : filename
    }

    private enum Constants {
        static let offRouteDistanceMeters = 50.0
        static let routeRecoveryDistanceMeters = 30.0
        static let arrivalDistanceMeters = 30.0
        static let approachDistanceMeters = 100.0
        static let roadRerouteDistanceMeters = 75.0
        static let enduroLookAheadMeters = 35.0
        static let minimumRerouteIntervalSeconds: TimeInterval = 15
        static let minimumSearchCharacters = 2
        static let searchDebounceMilliseconds = 300
        static let maximumSearchResults = 8
        static let halfCircleDegrees = 180.0
        static let fullCircleDegrees = 360.0
        static let roadStepAdvanceDistanceMeters = 30.0
        static let roadStepDistanceAdvantageMeters = 10.0
        static let focusMapStyleID = "focus"
    }

    private enum CompletionReason: Equatable {
        case destinationReached
        case navigationEnded
        case trailComplete
        case trailEnded
        case exitPointReached
        case exitNavigationEnded
        case rideRecorded

        var title: String {
            switch self {
            case .destinationReached: "Destination reached"
            case .navigationEnded: "Navigation ended"
            case .trailComplete: "Trail complete"
            case .trailEnded: "Trail ended"
            case .exitPointReached: "Exit point reached"
            case .exitNavigationEnded: "Exit navigation ended"
            case .rideRecorded: "Ride recorded"
            }
        }

        var emitsSuccessFeedback: Bool {
            switch self {
            case .destinationReached, .trailComplete, .exitPointReached, .rideRecorded:
                true
            case .navigationEnded, .trailEnded, .exitNavigationEnded:
                false
            }
        }

        var isAutomaticArrival: Bool {
            switch self {
            case .destinationReached, .trailComplete, .exitPointReached:
                true
            case .navigationEnded, .trailEnded, .exitNavigationEnded, .rideRecorded:
                false
            }
        }
    }
}

private struct RideNavigationLocationSnapshot {
    let coordinate: GeographicCoordinate?
    let horizontalAccuracyMeters: Double?
    let courseDegrees: Double?
    let courseAccuracyDegrees: Double?
    let altitudeMeters: Double?
    let observedAt: Date?

    init(
        coordinate: GeographicCoordinate? = nil,
        horizontalAccuracyMeters: Double? = nil,
        courseDegrees: Double? = nil,
        courseAccuracyDegrees: Double? = nil,
        altitudeMeters: Double? = nil,
        observedAt: Date? = nil
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.courseDegrees = courseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.altitudeMeters = altitudeMeters
        self.observedAt = observedAt
    }
}

private extension MiniMapPosition {
    init(_ position: RideNavigationMiniViewState.Position) {
        self.init(
            horizontalFraction: position.horizontalFraction,
            verticalFraction: position.verticalFraction
        )
    }
}

private extension RideNavigationMiniViewState.Position {
    init(_ position: MiniMapPosition) {
        self.init(
            horizontalFraction: position.horizontalFraction,
            verticalFraction: position.verticalFraction
        )
    }
}
// swiftlint:enable file_length
