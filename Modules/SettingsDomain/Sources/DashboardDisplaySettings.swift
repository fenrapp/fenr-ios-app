public enum DashboardProgressBarMode: String, Codable, CaseIterable, Sendable {
    case energy
    case speed
    case hidden
}

public enum DashboardBatteryIndicatorMode: String, Codable, CaseIterable, Sendable {
    case percentage
    case estimatedRange
}

public enum DashboardDeviceBatteryDisplayMode: String, Codable, CaseIterable, Sendable {
    case iconAndText
    case textOnly
    case iconOnly
    case hidden

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "icon", Self.iconAndText.rawValue:
            self = .iconAndText
        case "text", Self.textOnly.rawValue:
            self = .textOnly
        case Self.iconOnly.rawValue:
            self = .iconOnly
        case Self.hidden.rawValue:
            self = .hidden
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported dashboard device battery display mode"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var nextVisibleMode: Self {
        switch self {
        case .iconAndText: .textOnly
        case .textOnly: .iconOnly
        case .iconOnly, .hidden: .iconAndText
        }
    }
}
