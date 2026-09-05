import BLETraceDomain

enum BLETraceCaptureExpectation {
    case active
    case inactive

    init(isActive: Bool) {
        self = isActive ? .active : .inactive
    }

    func matches(_ sessions: [BLETraceSessionSummary]) -> Bool {
        let hasActiveSession = sessions.contains { $0.status == .active }
        return switch self {
        case .active: hasActiveSession
        case .inactive: !hasActiveSession
        }
    }
}
