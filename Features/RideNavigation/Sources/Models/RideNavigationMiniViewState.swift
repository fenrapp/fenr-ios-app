public struct RideNavigationMiniViewState: Equatable, Sendable {
    public enum Corner: Equatable, Sendable {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }

    public let mapScene: NavigationMapScene
    public let corner: Corner
    public let statusText: String?
    public let accessibilityLabel: String

    public init(
        mapScene: NavigationMapScene = .init(displayStyle: .focus),
        corner: Corner = .topTrailing,
        statusText: String? = nil,
        accessibilityLabel: String = "Mini navigation map"
    ) {
        self.mapScene = mapScene
        self.corner = corner
        self.statusText = statusText
        self.accessibilityLabel = accessibilityLabel
    }
}
