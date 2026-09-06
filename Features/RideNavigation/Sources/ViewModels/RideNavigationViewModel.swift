import Combine
import EnvironmentDomain
import Foundation
import RideNavigationDomain
import SettingsDomain
import VehicleSession

@MainActor
public final class RideNavigationViewModel: ObservableObject {
    @Published public internal(set) var viewState = RideNavigationViewState()
    @Published public internal(set) var miniViewState = RideNavigationMiniViewState()
    @Published public internal(set) var exportRequest: GPXExportRequest?
    @Published public internal(set) var shareRequest: GPXExportRequest?

    let dependencies: RideNavigationViewModelDependencies
    let state: RideNavigationViewModelState
    let operations = RideNavigationOperationStore()

    public init(
        dependencies: RideNavigationViewModelDependencies,
        recorder: RideRouteRecorder,
        breadcrumbRecorder: RideRouteRecorder
    ) {
        self.dependencies = dependencies
        state = RideNavigationViewModelState(
            recorder: recorder,
            breadcrumbRecorder: breadcrumbRecorder
        )
    }

    deinit {
        operations.invalidateAll(preserving: [.completedRouteSave])
    }

    var vehicleSession: any VehicleSessionService { dependencies.vehicleSession }
    var observeDeviceSpeed: ObserveDeviceSpeedUseCase { dependencies.observeDeviceSpeed }
    var roadRouteCalculator: any RoadRouteCalculating { dependencies.planning.roadRouteCalculator }
    var externalMapLinkResolver: any ExternalMapLinkResolving { dependencies.planning.externalMapLinkResolver }
    var trailExitFinder: any TrailExitFinding { dependencies.planning.trailExitFinder }
    var trailGuidance: RideNavigationTrailGuidanceController { dependencies.trailGuidance }
    var trailMapPreparer: any RideNavigationTrailMapPreparing { dependencies.trailMapPreparer }
    var trailMap: RideNavigationTrailMapController { dependencies.trailMap }
    var guidance: any NavigationGuidanceClient { dependencies.guidance }
    var loadSettings: LoadAppSettingsUseCase { dependencies.loadSettings }
    var observeSettings: ObserveAppSettingsUseCase { dependencies.observeSettings }
    var saveSettings: SaveAppSettingsUseCase { dependencies.saveSettings }
    var mapper: RideNavigationPresentationMapper { dependencies.presentationMapper }
    var mapMapper: RideNavigationMapPresentationMapper { dependencies.mapPresentationMapper }
    var mapSceneBuilder: RideNavigationMapSceneBuilder { dependencies.mapSceneBuilder }
    var searchService: RideNavigationSearchService { dependencies.searchService }
    var locationGeometry: RideNavigationLocationGeometry { dependencies.locationGeometry }
    var timing: RideNavigationTiming { dependencies.timing }
    var now: @Sendable () -> Date { timing.now }

    var observationTask: Task<Void, Never>? {
        get { operations[.vehicleObservation] }
        set { operations[.vehicleObservation] = newValue }
    }
    var locationObservationTask: Task<Void, Never>? {
        get { operations[.locationObservation] }
        set { operations[.locationObservation] = newValue }
    }
    var clockTask: Task<Void, Never>? {
        get { operations[.clock] }
        set { operations[.clock] = newValue }
    }
    var searchTask: Task<Void, Never>? {
        get { operations[.search] }
        set { operations[.search] = newValue }
    }
    var routeTask: Task<Void, Never>? {
        get { operations[.route] }
        set { operations[.route] = newValue }
    }
    var externalLinkTask: Task<Void, Never>? {
        get { operations[.externalLink] }
        set { operations[.externalLink] = newValue }
    }
    var trailExitTask: Task<Void, Never>? {
        get { operations[.trailExit] }
        set { operations[.trailExit] = newValue }
    }
    var draftSaveTask: Task<Void, Never>? {
        get { operations[.draftSave] }
        set { operations[.draftSave] = newValue }
    }
    var loadingTask: Task<Void, Never>? {
        get { operations[.initialRoutes] }
        set { operations[.initialRoutes] = newValue }
    }
    var settingsLoadingTask: Task<Void, Never>? {
        get { operations[.initialSettings] }
        set { operations[.initialSettings] = newValue }
    }
    var settingsObservationTask: Task<Void, Never>? {
        get { operations[.settingsObservation] }
        set { operations[.settingsObservation] = newValue }
    }
    var settingsSaveTask: Task<Void, Never>? {
        get { operations[.settingsSave] }
        set { operations[.settingsSave] = newValue }
    }
    var routeSaveTask: Task<Void, Never>? {
        get { operations[.routeSave] }
        set { operations[.routeSave] = newValue }
    }
    var trailPreparationTask: Task<Void, Never>? {
        get { operations[.trailPreparation] }
        set { operations[.trailPreparation] = newValue }
    }
    var plannedRouteSaveTask: Task<Void, Never>? {
        get { operations[.plannedRouteSave] }
        set { operations[.plannedRouteSave] = newValue }
    }
    var completedRouteSaveTask: Task<Void, Never>? {
        get { operations[.completedRouteSave] }
        set { operations[.completedRouteSave] = newValue }
    }
    var voiceAnnouncementTask: Task<Void, Never>? {
        get { operations[.voiceAnnouncement] }
        set { operations[.voiceAnnouncement] = newValue }
    }
    var feedbackTask: Task<Void, Never>? {
        get { operations[.feedback] }
        set { operations[.feedback] = newValue }
    }
    var routeDeletionTasks: [UUID: Task<Void, Never>] {
        get { operations.routeDeletionTasks }
        set { operations.routeDeletionTasks = newValue }
    }
    var draftPersistenceTask: Task<Void, Never>? {
        get { operations[.draftPersistence] }
        set { operations[.draftPersistence] = newValue }
    }

    var isStarted: Bool { get { state.isStarted } set { state.isStarted = newValue } }
    var presentationMode: RideNavigationPresentationMode {
        get { state.presentationMode }
        set { state.presentationMode = newValue }
    }
    var vehicleSnapshot: VehicleSessionSnapshot {
        get { state.vehicleSnapshot }
        set { state.vehicleSnapshot = newValue }
    }
    var locationSnapshot: RideNavigationLocationSnapshot {
        get { state.locationSnapshot }
        set { state.locationSnapshot = newValue }
    }
    var latestDeviceSpeedKilometersPerHour: Double? {
        get { state.latestDeviceSpeedKilometersPerHour }
        set { state.latestDeviceSpeedKilometersPerHour = newValue }
    }
    var frozenMiniMapScene: NavigationMapScene? {
        get { state.frozenMiniMapScene }
        set { state.frozenMiniMapScene = newValue }
    }
    var miniCompletionTitle: String? {
        get { state.miniCompletionTitle }
        set { state.miniCompletionTitle = newValue }
    }
    var savedRoutes: [RideRoute] { get { state.savedRoutes } set { state.savedRoutes = newValue } }
    var searchResults: [NavigationPlace] { get { state.searchResults } set { state.searchResults = newValue } }
    var selectedRoute: RideRoute? { get { state.selectedRoute } set { state.selectedRoute = newValue } }
    var selectedDirection: RideRouteDirection {
        get { state.selectedDirection }
        set { state.selectedDirection = newValue }
    }
    var roadRoute: RoadNavigationRoute? {
        get { state.roadRoute }
        set {
            state.roadRouteRevision &+= 1
            state.roadRoute = newValue
        }
    }
    var roadRoutes: [RoadNavigationRoute] { get { state.roadRoutes } set { state.roadRoutes = newValue } }
    var selectedRoadRouteIndex: Int {
        get { state.selectedRoadRouteIndex }
        set { state.selectedRoadRouteIndex = newValue }
    }
    var activeRoadStepIndex: Int {
        get { state.activeRoadStepIndex }
        set { state.activeRoadStepIndex = newValue }
    }
    var announcedRoadStepIndex: Int? {
        get { state.announcedRoadStepIndex }
        set { state.announcedRoadStepIndex = newValue }
    }
    var selectedDestination: NavigationPlace? {
        get { state.selectedDestination }
        set { state.selectedDestination = newValue }
    }
    var roadNavigationPurpose: RoadNavigationPurpose? {
        get { state.roadNavigationPurpose }
        set { state.roadNavigationPurpose = newValue }
    }
    var trailExitPreview: TrailExitRoute? {
        get { state.trailExitPreview }
        set {
            state.trailExitPreviewRevision &+= 1
            state.trailExitPreview = newValue
        }
    }
    var pendingExternalDestination: NavigationPlace? {
        get { state.pendingExternalDestination }
        set { state.pendingExternalDestination = newValue }
    }
    var showsIncomingDestinationPrompt: Bool {
        get { state.showsIncomingDestinationPrompt }
        set { state.showsIncomingDestinationPrompt = newValue }
    }
    var openIncomingDestinationAfterSummary: Bool {
        get { state.openIncomingDestinationAfterSummary }
        set { state.openIncomingDestinationAfterSummary = newValue }
    }
    var recorder: RideRouteRecorder { get { state.recorder } set { state.recorder = newValue } }
    var breadcrumbRecorder: RideRouteRecorder {
        get { state.breadcrumbRecorder }
        set { state.breadcrumbRecorder = newValue }
    }
    var completedRecording: RideRoute? {
        get { state.completedRecording }
        set { state.completedRecording = newValue }
    }
    var trailProgress: RideRouteProgress? { get { state.trailProgress } set { state.trailProgress = newValue } }
    var activityStartedAt: Date? { get { state.activityStartedAt } set { state.activityStartedAt = newValue } }
    var mapSource: MapSourceDescriptor { get { state.mapSource } set { state.mapSource = newValue } }
    var mapDisplayStyle: NavigationMapDisplayStyle {
        get { state.mapDisplayStyle }
        set { state.mapDisplayStyle = newValue }
    }
    var cameraMode: NavigationMapCamera { get { state.cameraMode } set { state.cameraMode = newValue } }
    var searchQuery: String { get { state.searchQuery } set { state.searchQuery = newValue } }
    var errorText: String? { get { state.errorText } set { state.errorText = newValue } }
    var isVoiceMuted: Bool { get { state.isVoiceMuted } set { state.isVoiceMuted = newValue } }
    var isCalculatingRoadRoutes: Bool {
        get { state.isCalculatingRoadRoutes }
        set { state.isCalculatingRoadRoutes = newValue }
    }
    var isRerouting: Bool { get { state.isRerouting } set { state.isRerouting = newValue } }
    var isFindingTrailExit: Bool {
        get { state.isFindingTrailExit }
        set { state.isFindingTrailExit = newValue }
    }
    var didAnnounceOffRoute: Bool {
        get { state.didAnnounceOffRoute }
        set { state.didAnnounceOffRoute = newValue }
    }
    var lastRoadRerouteAt: Date? { get { state.lastRoadRerouteAt } set { state.lastRoadRerouteAt = newValue } }
    var summaryTitle: String { get { state.summaryTitle } set { state.summaryTitle = newValue } }
    var summaryDetail: String { get { state.summaryDetail } set { state.summaryDetail = newValue } }
    var appSettings: AppSettings { get { state.appSettings } set { state.appSettings = newValue } }
    var screen: RideNavigationViewState.Screen { get { state.screen } set { state.screen = newValue } }
    var activity: RideNavigationViewState.Activity { get { state.activity } set { state.activity = newValue } }

}
