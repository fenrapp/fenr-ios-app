public struct RideNavigationSettings: Codable, Equatable, Sendable {
    public var avoidsTolls: Bool
    public var avoidsHighways: Bool
    public var preferredMapStyle: RideNavigationMapStylePreference
    public var mapOrientation: RideNavigationMapOrientationPreference
    public var miniMapCorner: MiniMapCorner

    public init(
        avoidsTolls: Bool = false,
        avoidsHighways: Bool = false,
        preferredMapStyle: RideNavigationMapStylePreference = .focus,
        mapOrientation: RideNavigationMapOrientationPreference = .headingUp,
        miniMapCorner: MiniMapCorner = .topTrailing
    ) {
        self.avoidsTolls = avoidsTolls
        self.avoidsHighways = avoidsHighways
        self.preferredMapStyle = preferredMapStyle
        self.mapOrientation = mapOrientation
        self.miniMapCorner = miniMapCorner
    }

    private enum CodingKeys: String, CodingKey {
        case avoidsTolls
        case avoidsHighways
        case preferredMapStyle
        case mapOrientation
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
        miniMapCorner = try container.decodeIfPresent(
            MiniMapCorner.self,
            forKey: .miniMapCorner
        ) ?? .topTrailing
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

public enum MiniMapCorner: String, Codable, CaseIterable, Hashable, Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}
