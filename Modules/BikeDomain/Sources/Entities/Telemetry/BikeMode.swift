public enum BikeMode: Equatable, Sendable {
    case unknown
    case index(Int)

    public var displayIndex: Int? {
        switch self {
        case .unknown:
            nil
        case .index(let value):
            value
        }
    }

    public var powerModeConfigurationIndex: Int? {
        guard let displayIndex, 1 ... 5 ~= displayIndex else { return nil }
        return displayIndex - 1
    }
}
