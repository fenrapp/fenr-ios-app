public enum BikeSpeed: Equatable, Sendable {
    case unknown
    case known(kmh: Double, kmhX10: Int)

    public var kmh: Double? {
        switch self {
        case .unknown:
            nil
        case .known(let kmh, _):
            kmh
        }
    }
}
