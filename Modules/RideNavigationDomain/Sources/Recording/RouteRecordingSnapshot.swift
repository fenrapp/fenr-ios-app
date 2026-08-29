import Foundation

public enum RouteRecordingPhase: Equatable, Sendable {
    case idle
    case recording
    case paused
    case finished
}

public struct RouteRecordingSnapshot: Equatable, Sendable {
    public let phase: RouteRecordingPhase
    public let route: RideRoute?
    public let activeElapsedSeconds: TimeInterval

    public init(
        phase: RouteRecordingPhase = .idle,
        route: RideRoute? = nil,
        activeElapsedSeconds: TimeInterval = .zero
    ) {
        self.phase = phase
        self.route = route
        self.activeElapsedSeconds = activeElapsedSeconds
    }
}
