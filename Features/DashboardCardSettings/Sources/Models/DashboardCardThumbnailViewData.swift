public struct DashboardCardThumbnailViewData: Equatable, Sendable {
    public let style: Style
    public let systemImage: String
    public let accent: Accent

    public init(style: Style, systemImage: String, accent: Accent) {
        self.style = style
        self.systemImage = systemImage
        self.accent = accent
    }

    public enum Style: Equatable, Sendable {
        case gauge
        case charging
        case metrics
        case chart
        case battery
        case grid
        case attitude
        case altitude
        case compass
        case lock
        case settings
    }

    public enum Accent: Equatable, Sendable {
        case accent
        case positive
        case warning
        case critical
        case informational
    }
}
