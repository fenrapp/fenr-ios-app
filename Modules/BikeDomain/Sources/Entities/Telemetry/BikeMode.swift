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
}
