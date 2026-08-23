public enum BikeOdometer: Equatable, Sendable {
    case unknown
    case known(kilometers: Double, centiKilometers: UInt32)

    public var kilometers: Double? {
        switch self {
        case .unknown:
            nil
        case .known(let kilometers, _):
            kilometers
        }
    }
}
