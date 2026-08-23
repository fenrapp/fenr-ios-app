public enum MotorRPM: Equatable, Sendable {
    case unknown
    case known(Int)

    public var value: Int? {
        switch self {
        case .unknown:
            nil
        case .known(let value):
            value
        }
    }
}
