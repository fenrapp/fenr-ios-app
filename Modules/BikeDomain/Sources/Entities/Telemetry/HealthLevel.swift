public enum HealthLevel: Equatable, Sendable {
    case unknown
    case known(percent: Int)

    public var percent: Int? {
        switch self {
        case .unknown:
            nil
        case .known(let percent):
            percent
        }
    }
}
