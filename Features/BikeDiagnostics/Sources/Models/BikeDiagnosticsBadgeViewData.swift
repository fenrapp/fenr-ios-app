public struct BikeDiagnosticsBadgeViewData: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case unknown
        case off
        case neutral
        case on
        case charging
        case crawlForward
        case crawlReverse
        case charger
        case fault
    }

    public let kind: Kind
    public let title: String

    public var id: Kind { kind }

    public init(kind: Kind, title: String) {
        self.kind = kind
        self.title = title
    }
}
