public struct BatteryHealthBannerViewData: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        case fault
        case stale
        case monitoring
        case write
    }

    public let kind: Kind
    public let title: String
    public let message: String
    public let emphasis: BatteryHealthStatusEmphasis

    public var id: String { title }

    public init(
        kind: Kind,
        title: String,
        message: String,
        emphasis: BatteryHealthStatusEmphasis
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.emphasis = emphasis
    }
}
