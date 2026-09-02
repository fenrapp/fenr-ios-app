public enum BikeOnboardingConnectionState: Equatable, Sendable {
    case inProgress(BikeOnboardingConnectionPhase)
    case timedOut
    case authenticationFailed
    case pairingResetRequired
    case disconnected

    public var phase: BikeOnboardingConnectionPhase? {
        guard case .inProgress(let phase) = self else { return nil }
        return phase
    }

    public var isRecovery: Bool {
        phase == nil
    }

    public var title: String {
        switch self {
        case .inProgress(.finding): BikeOnboardingL10n.text(.bikeOnboardingConnectionFindingTitle)
        case .inProgress(.securing): BikeOnboardingL10n.text(.bikeOnboardingConnectionSecuringTitle)
        case .inProgress(.live): BikeOnboardingL10n.text(.bikeOnboardingConnectionLiveTitle)
        case .timedOut: BikeOnboardingL10n.text(.bikeOnboardingConnectionTimedOutTitle)
        case .authenticationFailed: BikeOnboardingL10n.text(.bikeOnboardingConnectionAuthenticationFailedTitle)
        case .pairingResetRequired: BikeOnboardingL10n.text(.bikeOnboardingConnectionPairingResetTitle)
        case .disconnected: BikeOnboardingL10n.text(.bikeOnboardingConnectionDisconnectedTitle)
        }
    }

    public var detail: String {
        switch self {
        case .inProgress(.finding):
            BikeOnboardingL10n.text(.bikeOnboardingConnectionFindingDetail)
        case .inProgress(.securing):
            BikeOnboardingL10n.text(.bikeOnboardingConnectionSecuringDetail)
        case .inProgress(.live):
            BikeOnboardingL10n.text(.bikeOnboardingConnectionLiveDetail)
        case .timedOut, .disconnected:
            BikeOnboardingL10n.text(.bikeOnboardingConnectionRetryDetail)
        case .authenticationFailed:
            BikeOnboardingL10n.text(.bikeOnboardingConnectionAuthenticationFailedDetail)
        case .pairingResetRequired:
            BikeOnboardingL10n.text(.bikeOnboardingConnectionPairingResetDetail)
        }
    }

    public var primaryActionTitle: String? {
        switch self {
        case .inProgress: nil
        case .timedOut: BikeOnboardingL10n.text(.bikeOnboardingActionTryAgain)
        case .authenticationFailed: BikeOnboardingL10n.text(.bikeOnboardingActionPairAgain)
        case .pairingResetRequired: BikeOnboardingL10n.text(.bikeOnboardingActionTryPairingAgain)
        case .disconnected: BikeOnboardingL10n.text(.bikeOnboardingActionReconnect)
        }
    }
}
import Foundation
