public struct RideNavigationForkGuidance: Equatable, Sendable {
    public enum Emphasis: Equatable, Sendable {
        case standard
        case warning
    }

    public let instructionText: String
    public let distanceText: String?
    public let systemImage: String
    public let emphasis: Emphasis

    public init(
        instructionText: String,
        distanceText: String? = nil,
        systemImage: String,
        emphasis: Emphasis = .standard
    ) {
        self.instructionText = instructionText
        self.distanceText = distanceText
        self.systemImage = systemImage
        self.emphasis = emphasis
    }
}
