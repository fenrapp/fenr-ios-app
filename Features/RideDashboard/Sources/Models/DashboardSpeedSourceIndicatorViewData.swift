public struct DashboardSpeedSourceIndicatorViewData: Equatable, Sendable {
    public enum Emphasis: Equatable, Sendable {
        case informational
        case warning
    }

    public let text: String
    public let systemImage: String
    public let emphasis: Emphasis

    public init(
        text: String,
        systemImage: String,
        emphasis: Emphasis = .informational
    ) {
        self.text = text
        self.systemImage = systemImage
        self.emphasis = emphasis
    }
}
