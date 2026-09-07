import Foundation
import Observation
import SettingsDomain
import VehicleSession

@MainActor
@Observable
public final class RideNavigationViewModel {
    public internal(set) var viewState = RideNavigationViewState()
    public internal(set) var miniViewState = RideNavigationMiniViewState()
    public internal(set) var settingsSaveError: String?
    public var exportRequest: GPXExportRequest? { library.snapshot.exportRequest }
    public var shareRequest: GPXExportRequest? { library.snapshot.shareRequest }

    let dependencies: RideNavigationViewModelDependencies
    let library: RideNavigationLibraryController
    let planningController: RideNavigationPlanningController
    let activityController: RideNavigationActivityController
    @ObservationIgnored var isStarted = false
    @ObservationIgnored var presentationMode = RideNavigationPresentationMode.fullScreen
    @ObservationIgnored var vehicleSnapshot = VehicleSessionSnapshot()
    @ObservationIgnored var locationSnapshot = RideNavigationLocationSnapshot()
    @ObservationIgnored var lastValidBatteryText: String?
    @ObservationIgnored var lastValidModeText: String?
    @ObservationIgnored var latestDeviceSpeedKilometersPerHour: Double?
    @ObservationIgnored var frozenMiniMapScene: NavigationMapScene?
    @ObservationIgnored var miniCompletionTitle: String?
    @ObservationIgnored var showsIncomingDestinationPrompt = false
    @ObservationIgnored var openIncomingDestinationAfterSummary = false
    @ObservationIgnored var mapSource = MapSourceDescriptor.appleStandard
    @ObservationIgnored var mapDisplayStyle = NavigationMapDisplayStyle.map
    @ObservationIgnored var cameraMode = NavigationMapCamera.automatic
    @ObservationIgnored var errorText: String?
    @ObservationIgnored var appSettings = AppSettings()
    @ObservationIgnored var screen = RideNavigationViewState.Screen.home
    @ObservationIgnored var pendingSettings = AppSettingsPendingChanges()
    @ObservationIgnored var lifecycleGeneration: UInt = 0
    @ObservationIgnored var vehicleObservationGeneration: UInt = 0
    @ObservationIgnored var locationObservationGeneration: UInt = 0
    @ObservationIgnored var settingsObservationGeneration: UInt = 0
    @ObservationIgnored var settingsLoadingGeneration: UInt = 0
    @ObservationIgnored var settingsWorkerGeneration: UInt64 = 0
    @ObservationIgnored var observationTask: Task<Void, Never>?
    @ObservationIgnored var locationObservationTask: Task<Void, Never>?
    @ObservationIgnored var settingsLoadingTask: Task<Void, Never>?
    @ObservationIgnored var settingsObservationTask: Task<Void, Never>?
    @ObservationIgnored var settingsSaveTask: Task<Void, Never>?
    @ObservationIgnored var libraryObservationTask: Task<Void, Never>?
    @ObservationIgnored var planningObservationTask: Task<Void, Never>?
    @ObservationIgnored var activityObservationTask: Task<Void, Never>?

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
