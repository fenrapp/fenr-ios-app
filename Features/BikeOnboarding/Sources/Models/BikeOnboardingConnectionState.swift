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
        case .inProgress(.finding): "Finding your bike."
        case .inProgress(.securing): "Securing the connection."
        case .inProgress(.live): "Waiting for telemetry."
        case .timedOut: "We couldn't reach your bike."
        case .authenticationFailed: "Pairing wasn't accepted."
        case .pairingResetRequired: "Reset the saved pairing."
        case .disconnected: "Connection was interrupted."
        }
    }

    public var detail: String {
        switch self {
        case .inProgress(.finding):
            "Keep your bike on and nearby."
        case .inProgress(.securing):
            "Confirm the iOS pairing request if it appears. Your code is already copied."
        case .inProgress(.live):
            "FENR will finish setup after the first live update."
        case .timedOut, .disconnected:
            "Keep the bike on and nearby, then try again."
        case .authenticationFailed:
            "Confirm the six-digit code in the iOS prompt, then try again."
        case .pairingResetRequired:
            "In Settings > Bluetooth, forget this bike. Then return to FENR and pair again."
        }
    }

    public var primaryActionTitle: String? {
        switch self {
        case .inProgress: nil
        case .timedOut: "Try Again"
        case .authenticationFailed: "Pair Again"
        case .pairingResetRequired: "Try Pairing Again"
        case .disconnected: "Reconnect"
        }
    }
}
