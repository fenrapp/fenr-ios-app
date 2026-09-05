import Foundation

public struct BLETraceRecordingFailure: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case preparing
        case opening
        case writing
        case finishing
    }

    public let sessionID: UUID?
    public let phase: Phase

    public init(sessionID: UUID?, phase: Phase) {
        self.sessionID = sessionID
        self.phase = phase
    }
}
