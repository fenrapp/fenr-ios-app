import Combine
import Foundation
import SettingsDomain
import VehicleSession

@MainActor
public final class RideNavigationViewModel: ObservableObject {
    @Published public internal(set) var viewState = RideNavigationViewState()
    @Published public internal(set) var miniViewState = RideNavigationMiniViewState()
    @Published public internal(set) var settingsSaveError: String?
    public var exportRequest: GPXExportRequest? { library.snapshot.exportRequest }
    public var shareRequest: GPXExportRequest? { library.snapshot.shareRequest }

    let dependencies: RideNavigationViewModelDependencies
    let library: RideNavigationLibraryController
    let planningController: RideNavigationPlanningController
    let activityController: RideNavigationActivityController
    var isStarted = false
    var presentationMode = RideNavigationPresentationMode.fullScreen
    var vehicleSnapshot = VehicleSessionSnapshot()
    var locationSnapshot = RideNavigationLocationSnapshot()
    var lastValidBatteryText: String?
    var lastValidModeText: String?
    var latestDeviceSpeedKilometersPerHour: Double?
    var frozenMiniMapScene: NavigationMapScene?
    var miniCompletionTitle: String?
    var showsIncomingDestinationPrompt = false
    var openIncomingDestinationAfterSummary = false
    var mapSource = MapSourceDescriptor.appleStandard
    var mapDisplayStyle = NavigationMapDisplayStyle.map
    var cameraMode = NavigationMapCamera.automatic
    var errorText: String?
    var appSettings = AppSettings()
    var screen = RideNavigationViewState.Screen.home
    var pendingSettings = AppSettingsPendingChanges()
    var lifecycleGeneration: UInt = 0
    var vehicleObservationGeneration: UInt = 0
    var locationObservationGeneration: UInt = 0
    var settingsObservationGeneration: UInt = 0
    var settingsLoadingGeneration: UInt = 0
    var settingsWorkerGeneration: UInt64 = 0
    var observationTask: Task<Void, Never>?
    var locationObservationTask: Task<Void, Never>?
    var settingsLoadingTask: Task<Void, Never>?
    var settingsObservationTask: Task<Void, Never>?
    var settingsSaveTask: Task<Void, Never>?
    var libraryObservationTask: Task<Void, Never>?
    var planningObservationTask: Task<Void, Never>?
    var activityObservationTask: Task<Void, Never>?

    public init(
        dependencies: RideNavigationViewModelDependencies,
        library: RideNavigationLibraryController,
        planningController: RideNavigationPlanningController,
        activityController: RideNavigationActivityController
    ) {
        self.dependencies = dependencies
        self.library = library
        self.planningController = planningController
        self.activityController = activityController
    }

    deinit {
        observationTask?.cancel()
        locationObservationTask?.cancel()
        settingsLoadingTask?.cancel()
        settingsObservationTask?.cancel()
        settingsSaveTask?.cancel()
        libraryObservationTask?.cancel()
        planningObservationTask?.cancel()
        activityObservationTask?.cancel()
    }
}
