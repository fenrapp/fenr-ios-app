public struct PowerModeControlFeedback: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case idle
        case applying
        case confirmed
        case failed
    }

    public let state: State
    public let title: String?
    public let systemImage: String?
    public let emphasis: PowerModeStatusEmphasis
    public let isActivity: Bool

    public init(
        state: State,
        title: String? = nil,
        systemImage: String? = nil,
        emphasis: PowerModeStatusEmphasis = .neutral,
        isActivity: Bool = false
    ) {
        self.state = state
        self.title = title
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.isActivity = isActivity
    }

    public static let idle = PowerModeControlFeedback(state: .idle)
}
