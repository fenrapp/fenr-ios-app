import EnvironmentDomain
import Foundation
import RideNavigationDomain
import SettingsDomain
import VehicleSession

@MainActor
final class RideNavigationViewModelState {
    var isStarted = false
    var presentationMode = RideNavigationPresentationMode.fullScreen
    var vehicleSnapshot = VehicleSessionSnapshot()
    var locationSnapshot = RideNavigationLocationSnapshot()
    var lastValidBatteryText: String?
    var lastValidModeText: String?
    var latestDeviceSpeedKilometersPerHour: Double?
    var frozenMiniMapScene: NavigationMapScene?
    var miniCompletionTitle: String?
    var activeRoadStepIndex = 0
    var announcedRoadStepIndex: Int?
    var showsIncomingDestinationPrompt = false
    var openIncomingDestinationAfterSummary = false
    var recorder: RideRouteRecorder
    var breadcrumbRecorder: RideRouteRecorder
    var completedRecording: RideRoute?
    var trailProgress: RideRouteProgress?
    var activityStartedAt: Date?
    var mapSource = MapSourceDescriptor.appleStandard
    var mapDisplayStyle = NavigationMapDisplayStyle.map
    var cameraMode = NavigationMapCamera.automatic
    var errorText: String?
    var isVoiceMuted = false
    var didAnnounceOffRoute = false
    var summaryTitle = String(localized: .rideNavigationSummaryRideComplete)
    var summaryDetail = ""
    var summaryIsSuccessful = true
    var appSettings = AppSettings()
    var screen = RideNavigationViewState.Screen.home
    var activity = RideNavigationViewState.Activity.preview

    init(recorder: RideRouteRecorder, breadcrumbRecorder: RideRouteRecorder) {
        self.recorder = recorder
        self.breadcrumbRecorder = breadcrumbRecorder
    }
}

struct RideNavigationLocationSnapshot {
    let coordinate: GeographicCoordinate?
    let horizontalAccuracyMeters: Double?
    let courseDegrees: Double?
    let courseAccuracyDegrees: Double?
    let altitudeMeters: Double?
    let verticalAccuracyMeters: Double?
    let observedAt: Date?

    init(
        coordinate: GeographicCoordinate? = nil,
        horizontalAccuracyMeters: Double? = nil,
        courseDegrees: Double? = nil,
        courseAccuracyDegrees: Double? = nil,
        altitudeMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        observedAt: Date? = nil
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.courseDegrees = courseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.altitudeMeters = altitudeMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.observedAt = observedAt
    }
}
