public enum RideNavigationLineGroup: String, Codable, CaseIterable, Sendable {
    case pendingRoute
    case activeSection
    case completedRoute
    case recording
    case connector
}

public enum RideNavigationLineThickness: String, Codable, CaseIterable, Sendable {
    case thin
    case regular
    case thick
}

public struct RideNavigationLineColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return .zero }
        return min(max(value, .zero), 1)
    }
}

public struct RideNavigationLineAppearance: Codable, Equatable, Sendable {
    public var color: RideNavigationLineColor
    public var thickness: RideNavigationLineThickness

    public init(
        color: RideNavigationLineColor,
        thickness: RideNavigationLineThickness
    ) {
        self.color = color
        self.thickness = thickness
    }
}

public struct RideNavigationLineAppearances: Codable, Equatable, Sendable {
    public var pendingRoute: RideNavigationLineAppearance
    public var activeSection: RideNavigationLineAppearance
    public var completedRoute: RideNavigationLineAppearance
    public var recording: RideNavigationLineAppearance
    public var connector: RideNavigationLineAppearance

    public init(
        pendingRoute: RideNavigationLineAppearance = .init(
            color: .init(red: 0, green: 0.478, blue: 1),
            thickness: .regular
        ),
        activeSection: RideNavigationLineAppearance = .init(
            color: .init(red: 0.196, green: 0.678, blue: 0.902),
            thickness: .thick
        ),
        completedRoute: RideNavigationLineAppearance = .init(
            color: .init(red: 0.557, green: 0.557, blue: 0.576),
            thickness: .regular
        ),
        recording: RideNavigationLineAppearance = .init(
            color: .init(red: 1, green: 0.231, blue: 0.188),
            thickness: .regular
        ),
        connector: RideNavigationLineAppearance = .init(
            color: .init(red: 0, green: 0.478, blue: 0.478),
            thickness: .regular
        )
    ) {
        self.pendingRoute = pendingRoute
        self.activeSection = activeSection
        self.completedRoute = completedRoute
        self.recording = recording
        self.connector = connector
    }

    public subscript(group: RideNavigationLineGroup) -> RideNavigationLineAppearance {
        get {
            switch group {
            case .pendingRoute: pendingRoute
            case .activeSection: activeSection
            case .completedRoute: completedRoute
            case .recording: recording
            case .connector: connector
            }
        }
        set {
            switch group {
            case .pendingRoute: pendingRoute = newValue
            case .activeSection: activeSection = newValue
            case .completedRoute: completedRoute = newValue
            case .recording: recording = newValue
            case .connector: connector = newValue
            }
        }
    }
}
