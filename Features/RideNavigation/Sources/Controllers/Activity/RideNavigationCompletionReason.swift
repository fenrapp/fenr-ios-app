import Foundation

enum RideNavigationCompletionReason: Equatable, Sendable {
    case destinationReached
    case navigationEnded
    case trailComplete
    case trailEnded
    case exitPointReached
    case exitNavigationEnded
    case rideRecorded

    var title: String {
        switch self {
        case .destinationReached: String(localized: .rideNavigationSummaryDestinationReached)
        case .navigationEnded: String(localized: .rideNavigationSummaryNavigationEnded)
        case .trailComplete: String(localized: .rideNavigationSummaryTrailComplete)
        case .trailEnded: String(localized: .rideNavigationSummaryTrailEnded)
        case .exitPointReached: String(localized: .rideNavigationSummaryExitPointReached)
        case .exitNavigationEnded: String(localized: .rideNavigationSummaryExitNavigationEnded)
        case .rideRecorded: String(localized: .rideNavigationSummaryRideRecorded)
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
