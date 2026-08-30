public enum BikeChargerType: Equatable, Sendable {
    case standard
    case fast
    case backpack
    case unknown(Int)

    public init(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .standard
        case 2:
            self = .fast
        case 3:
            self = .backpack
        default:
            self = .unknown(rawValue)
        }
    }

    public var rawValue: Int {
        switch self {
        case .standard:
            0
        case .fast:
            2
        case .backpack:
            3
        case .unknown(let rawValue):
            rawValue
        }
    }

    public var maximumChargePowerWatts: Int {
        switch self {
        case .fast:
            7_000
        case .standard, .backpack, .unknown:
            3_300
        }
    }
}
