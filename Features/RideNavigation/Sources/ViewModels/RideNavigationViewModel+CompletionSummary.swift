import Foundation

@MainActor
extension RideNavigationViewModel {
    var canExportCompletedRoute: Bool {
        (activityController.snapshot.completion?.isSuccessful ?? true)
            && (activityController.snapshot.completedRecording != nil
                || planningController.snapshot.selectedRoute != nil
                || planningController.snapshot.roadRoute != nil)
    }

    var summaryTitle: String {
        guard let completion = activityController.snapshot.completion else {
            return String(localized: .rideNavigationSummaryRideComplete)
        }
        return completion.isSuccessful ? completion.reason.title : String(localized: .rideNavigationRecordingEnded)
    }

    var summaryDetail: String {
        guard let completion = activityController.snapshot.completion else { return "" }
        guard completion.hasGPSPoints else { return String(localized: .rideNavigationNoValidGPSPoints) }
        let distance = dependencies.presentationMapper.distance(
            meters: completion.distanceMeters, measurementSystem: measurementSystem
        )
        let elapsed = dependencies.presentationMapper.elapsed(completion.elapsedSeconds)
        return completion.distanceFirst ? "\(distance) \u{00B7} \(elapsed)" : "\(elapsed) \u{00B7} \(distance)"
    }
}
