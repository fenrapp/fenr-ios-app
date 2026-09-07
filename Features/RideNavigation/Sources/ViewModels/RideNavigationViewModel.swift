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
    public var exportRequest: GPXExportRequest? { library.snapshot.exportRequest }
    public var shareRequest: GPXExportRequest? { library.snapshot.shareRequest }
    @Published public internal(set) var settingsSaveError: String?

    var pendingSettings = AppSettingsPendingChanges()
    var settingsWorkerGeneration: UInt64 = 0

    let planningController: RideNavigationPlanningController
    var planningObservationTask: Task<Void, Never>?
    let library: RideNavigationLibraryController
    var libraryObservationTask: Task<Void, Never>?
    let dependencies: RideNavigationViewModelDependencies
    let state: RideNavigationViewModelState
    let operations = RideNavigationOperationStore()

    public init(
        dependencies: RideNavigationViewModelDependencies,
        library: RideNavigationLibraryController,
        planningController: RideNavigationPlanningController,
        recorder: RideRouteRecorder,
        breadcrumbRecorder: RideRouteRecorder
    ) {
        self.dependencies = dependencies
        self.library = library
        self.planningController = planningController
        state = RideNavigationViewModelState(
            recorder: recorder,
            breadcrumbRecorder: breadcrumbRecorder
        )
    }

    deinit {
        planningObservationTask?.cancel()
        libraryObservationTask?.cancel()
        operations.invalidateAll()
    }

    var vehicleSession: any VehicleSessionService { dependencies.vehicleSession }
    var observeDeviceSpeed: ObserveDeviceSpeedUseCase { dependencies.observeDeviceSpeed }
    var trailGuidance: RideNavigationTrailGuidanceController { dependencies.trailGuidance }
    var trailMapPreparer: any RideNavigationTrailMapPreparing { dependencies.trailMapPreparer }
    var trailMap: RideNavigationTrailMapController { dependencies.trailMap }
    var guidance: any NavigationGuidanceClient { dependencies.guidance }
    var loadSettings: LoadAppSettingsUseCase { dependencies.loadSettings }
    var observeSettings: ObserveAppSettingsUseCase { dependencies.observeSettings }
    var updateSettings: UpdateAppSettingsUseCase { dependencies.updateSettings }
    var mapper: RideNavigationPresentationMapper { dependencies.presentationMapper }
    var mapMapper: RideNavigationMapPresentationMapper { dependencies.mapPresentationMapper }
    var mapSceneBuilder: RideNavigationMapSceneBuilder { dependencies.mapSceneBuilder }
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
    var trailPreparationTask: Task<Void, Never>? {
        get { operations[.trailPreparation] }
        set { operations[.trailPreparation] = newValue }
    }
    var voiceAnnouncementTask: Task<Void, Never>? {
        get { operations[.voiceAnnouncement] }
        set { operations[.voiceAnnouncement] = newValue }
    }
    var feedbackTask: Task<Void, Never>? {
        get { operations[.feedback] }
        set { operations[.feedback] = newValue }
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
    var activeRoadStepIndex: Int {
        get { state.activeRoadStepIndex }
        set { state.activeRoadStepIndex = newValue }
    }
    var announcedRoadStepIndex: Int? {
        get { state.announcedRoadStepIndex }
        set { state.announcedRoadStepIndex = newValue }
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
    var errorText: String? { get { state.errorText } set { state.errorText = newValue } }
    var isVoiceMuted: Bool { get { state.isVoiceMuted } set { state.isVoiceMuted = newValue } }
    var didAnnounceOffRoute: Bool {
        get { state.didAnnounceOffRoute }
        set { state.didAnnounceOffRoute = newValue }
    }
    var summaryTitle: String { get { state.summaryTitle } set { state.summaryTitle = newValue } }
    var summaryDetail: String { get { state.summaryDetail } set { state.summaryDetail = newValue } }
    var appSettings: AppSettings { get { state.appSettings } set { state.appSettings = newValue } }
    var screen: RideNavigationViewState.Screen { get { state.screen } set { state.screen = newValue } }
    var activity: RideNavigationViewState.Activity { get { state.activity } set { state.activity = newValue } }

}
