public enum BikeVariant: Equatable, Sendable {
    case mx
    case ex
    case sm
    case unknown

    public init(vin: String) {
        switch vin.prefix(5) {
        case "UDUMX": self = .mx
        case "UDUEX": self = .ex
        case "UDUSM": self = .sm
        default: self = .unknown
        }
    }
}
