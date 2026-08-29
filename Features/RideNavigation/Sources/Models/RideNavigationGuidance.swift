public struct RideNavigationGuidance: Equatable, Sendable {
    public enum Emphasis: Equatable, Sendable {
        case standard
        case warning
    }

    public let text: String
    public let detail: String?
    public let systemImage: String
    public let rotationDegrees: Double
    public let emphasis: Emphasis

    public init(
        text: String,
        detail: String? = nil,
        systemImage: String,
        rotationDegrees: Double = .zero,
        emphasis: Emphasis
    ) {
        self.text = text
        self.detail = detail
        self.systemImage = systemImage
        self.rotationDegrees = rotationDegrees
        self.emphasis = emphasis
    }
}
