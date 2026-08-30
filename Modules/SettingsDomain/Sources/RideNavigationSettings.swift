public struct RideNavigationSettings: Codable, Equatable, Sendable {
    public var avoidsTolls: Bool
    public var avoidsHighways: Bool
    public var preferredMapStyle: RideNavigationMapStylePreference
    public var mapOrientation: RideNavigationMapOrientationPreference
    public var miniMapPosition: MiniMapPosition
    public var miniMapScale: MiniMapScale
    public var miniMapLayoutOrientation: MiniMapLayoutOrientation

    public init(
        avoidsTolls: Bool = false,
        avoidsHighways: Bool = false,
        preferredMapStyle: RideNavigationMapStylePreference = .focus,
        mapOrientation: RideNavigationMapOrientationPreference = .headingUp,
        miniMapPosition: MiniMapPosition = .topTrailing,
        miniMapScale: MiniMapScale = .initial,
        miniMapLayoutOrientation: MiniMapLayoutOrientation = .portrait
    ) {
        self.avoidsTolls = avoidsTolls
        self.avoidsHighways = avoidsHighways
        self.preferredMapStyle = preferredMapStyle
        self.mapOrientation = mapOrientation
        self.miniMapPosition = miniMapPosition
        self.miniMapScale = miniMapScale
        self.miniMapLayoutOrientation = miniMapLayoutOrientation
    }

    private enum CodingKeys: String, CodingKey {
        case avoidsTolls
        case avoidsHighways
        case preferredMapStyle
        case mapOrientation
        case miniMapPosition
        case miniMapScale
        case miniMapLayoutOrientation
        case miniMapCorner
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        avoidsTolls = try container.decodeIfPresent(Bool.self, forKey: .avoidsTolls) ?? false
        avoidsHighways = try container.decodeIfPresent(Bool.self, forKey: .avoidsHighways) ?? false
        preferredMapStyle = try container.decodeIfPresent(
            RideNavigationMapStylePreference.self,
            forKey: .preferredMapStyle
        ) ?? .focus
        mapOrientation = try container.decodeIfPresent(
            RideNavigationMapOrientationPreference.self,
            forKey: .mapOrientation
        ) ?? .headingUp
        if let position = try container.decodeIfPresent(MiniMapPosition.self, forKey: .miniMapPosition) {
            miniMapPosition = position
        } else {
            let legacyCorner = try container.decodeIfPresent(LegacyMiniMapCorner.self, forKey: .miniMapCorner)
            miniMapPosition = legacyCorner.map(MiniMapPosition.init) ?? .topTrailing
        }
        miniMapScale = try container.decodeIfPresent(MiniMapScale.self, forKey: .miniMapScale) ?? .initial
        miniMapLayoutOrientation = try container.decodeIfPresent(
            MiniMapLayoutOrientation.self,
            forKey: .miniMapLayoutOrientation
        ) ?? .portrait
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(avoidsTolls, forKey: .avoidsTolls)
        try container.encode(avoidsHighways, forKey: .avoidsHighways)
        try container.encode(preferredMapStyle, forKey: .preferredMapStyle)
        try container.encode(mapOrientation, forKey: .mapOrientation)
        try container.encode(miniMapPosition, forKey: .miniMapPosition)
        try container.encode(miniMapScale, forKey: .miniMapScale)
        try container.encode(miniMapLayoutOrientation, forKey: .miniMapLayoutOrientation)
    }
}

public enum RideNavigationMapStylePreference: String, Codable, CaseIterable, Sendable {
    case focus
    case standard
    case satellite
}

public enum RideNavigationMapOrientationPreference: String, Codable, CaseIterable, Sendable {
    case northUp
    case headingUp
}

public struct MiniMapPosition: Codable, Equatable, Sendable {
    public static let topTrailing = MiniMapPosition(horizontalFraction: 0.85, verticalFraction: 0.35)

    public let horizontalFraction: Double
    public let verticalFraction: Double

    public init(horizontalFraction: Double, verticalFraction: Double) {
        self.horizontalFraction = Self.clamp(horizontalFraction)
        self.verticalFraction = Self.clamp(verticalFraction)
    }

    private enum CodingKeys: String, CodingKey {
        case horizontalFraction
        case verticalFraction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            horizontalFraction: try container.decode(Double.self, forKey: .horizontalFraction),
            verticalFraction: try container.decode(Double.self, forKey: .verticalFraction)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public struct MiniMapScale: Codable, Equatable, Sendable {
    public static let minimumValue = 0.5
    public static let maximumValue = 1.5
    public static let initial = MiniMapScale(1.1)

    public let value: Double

    public init(_ value: Double) {
        self.value = min(max(value, Self.minimumValue), Self.maximumValue)
    }

    public init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(Double.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public enum MiniMapLayoutOrientation: String, Codable, Sendable {
    case portrait
    case landscape
}

private enum LegacyMiniMapCorner: String, Codable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

private extension MiniMapPosition {
    init(_ corner: LegacyMiniMapCorner) {
        switch corner {
        case .topLeading:
            self.init(horizontalFraction: 0.15, verticalFraction: 0.35)
        case .topTrailing:
            self.init(horizontalFraction: 0.85, verticalFraction: 0.35)
        case .bottomLeading:
            self.init(horizontalFraction: 0.15, verticalFraction: 0.65)
        case .bottomTrailing:
            self.init(horizontalFraction: 0.85, verticalFraction: 0.65)
        }
    }
}
