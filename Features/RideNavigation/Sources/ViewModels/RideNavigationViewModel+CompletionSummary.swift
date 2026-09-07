import Foundation
import RideNavigationDomain

@MainActor
extension RideNavigationViewModel {
    var canExportCompletedRoute: Bool {
        state.summaryIsSuccessful && (completedRecording != nil || selectedRoute != nil || roadRoute != nil)
    }

    func prepareCompletionSummary(
        reason: CompletionReason,
        finishedActivity: RideNavigationViewState.Activity,
        at date: Date
    ) -> RideRoute? {
        if reason == .rideRecorded {
            completedRecording = recorder.finish(at: date)
            summaryDetail = completedRecording.map { route in
                let distance = mapper.distance(
                    meters: route.distanceMeters,
                    measurementSystem: measurementSystem
                )
                return "\(distance) \u{00B7} \(elapsedText(at: date))"
            } ?? String(localized: .rideNavigationNoValidGPSPoints)
            library.clearDraft()
            return nil
        }
        guard finishedActivity == .following else {
            summaryDetail = "\(elapsedText(at: date)) \u{00B7} \(currentDistanceText)"
            return nil
        }
        guard let breadcrumb = breadcrumbRecorder.finish(at: date) else {
            completedRecording = nil
            library.resetPersistence()
            summaryDetail = String(localized: .rideNavigationNoValidGPSPoints)
            return nil
        }
        let route = RideRoute(
            id: UUID(),
            name: String(localized: .rideNavigationRideWithTrailName(
                selectedRoute?.name ?? String(localized: .rideNavigationTrailName)
            )),
            createdAt: breadcrumb.createdAt,
            updatedAt: date,
            segments: breadcrumb.segments
        )
        completedRecording = route
        let distance = mapper.distance(
            meters: route.distanceMeters,
            measurementSystem: measurementSystem
        )
        summaryDetail = "\(distance) \u{00B7} \(elapsedText(at: date))"
        return route
    }

}
