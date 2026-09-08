public enum DashboardProgressBarThickness: String, Codable, CaseIterable, Sendable {
    case regular
    case thick

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case Self.regular.rawValue: self = .regular
        case Self.thick.rawValue, "extraThick": self = .thick
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported dashboard progress bar thickness"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
