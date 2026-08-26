public enum BikeVariant: String, Equatable, Sendable {
    case mx = "VARG_MX"
    case ex = "VARG_EX"
    case sm = "VARG_SM"
    case unknown

    public init(vin: String) {
        switch vin.prefix(5).uppercased() {
        case "UDUMX": self = .mx
        case "UDUEX": self = .ex
        case "UDUSM": self = .sm
        default: self = .unknown
        }
    }
}
