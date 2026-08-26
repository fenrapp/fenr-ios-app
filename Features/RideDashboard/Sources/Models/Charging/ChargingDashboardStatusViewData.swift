public struct ChargingDashboardStatusViewData: Equatable, Sendable {
    public let text: String
    public let systemImage: String
    public let emphasis: Emphasis
    public let showsActivityIndicator: Bool

    public init(
        text: String,
        systemImage: String,
        emphasis: Emphasis,
        showsActivityIndicator: Bool
    ) {
        self.text = text
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.showsActivityIndicator = showsActivityIndicator
    }

    public enum Emphasis: Equatable, Sendable {
        case power
        case target
        case general
        case failure
    }
}
