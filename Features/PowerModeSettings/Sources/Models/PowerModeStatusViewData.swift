public enum PowerModeStatusEmphasis: Equatable, Sendable {
    case neutral
    case informational
    case positive
    case warning
    case critical
}

public struct PowerModeStatusViewData: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let systemImage: String
    public let emphasis: PowerModeStatusEmphasis
    public let isActivity: Bool

    public init(
        title: String,
        detail: String,
        systemImage: String,
        emphasis: PowerModeStatusEmphasis,
        isActivity: Bool
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.isActivity = isActivity
    }
}
