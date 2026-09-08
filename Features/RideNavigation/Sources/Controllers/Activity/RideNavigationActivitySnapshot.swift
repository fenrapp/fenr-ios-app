import Foundation
import RideNavigationDomain

struct RideNavigationActivitySnapshot: Sendable {
    let activity: RideNavigationViewState.Activity
    let recording: RouteRecordingSnapshot
    let breadcrumb: RouteRecordingSnapshot
    let completedRecording: RideRoute?
    let trailProgress: RideRouteProgress?
    let activityStartedAt: Date?
    let elapsedSeconds: TimeInterval
    let activeRoadStepIndex: Int
    let isVoiceMuted: Bool
    let didAnnounceOffRoute: Bool
    let completion: RideNavigationActivityCompletion?
    let trailGuidance: RideNavigationTrailGuidanceController.Snapshot
    let trailMap: RideNavigationTrailMapController.PresentationSnapshot
    let trailOverviewCoordinates: [NavigationMapCoordinate]
    let trailDistanceMeters: Double
    let errorMessage: String?

    var hasActiveSession: Bool {
        [.following, .navigating, .recording, .paused].contains(activity)
    }
}
