public struct RideNavigationMiniViewState: Equatable, Sendable {
    public struct Position: Equatable, Sendable {
        public static let topTrailing = Position(horizontalFraction: 0.85, verticalFraction: 0.35)

        public let horizontalFraction: Double
        public let verticalFraction: Double

        public init(horizontalFraction: Double, verticalFraction: Double) {
            self.horizontalFraction = min(max(horizontalFraction, 0), 1)
            self.verticalFraction = min(max(verticalFraction, 0), 1)
        }
    }

    public let mapScene: NavigationMapScene
    public let position: Position
    public let scale: Double
    public let scaleRange: ClosedRange<Double>
    public let isLandscape: Bool
    public let statusText: String?
    public let accessibilityLabel: String

    public init(
        mapScene: NavigationMapScene = .init(displayStyle: .focus),
        position: Position = .topTrailing,
        scale: Double = 1.1,
        scaleRange: ClosedRange<Double> = 0.5 ... 1.5,
        isLandscape: Bool = false,
        statusText: String? = nil,
        accessibilityLabel: String = "Mini navigation map"
    ) {
        self.mapScene = mapScene
        self.position = position
        self.scale = min(max(scale, scaleRange.lowerBound), scaleRange.upperBound)
        self.scaleRange = scaleRange
        self.isLandscape = isLandscape
        self.statusText = statusText
        self.accessibilityLabel = accessibilityLabel
    }
}
