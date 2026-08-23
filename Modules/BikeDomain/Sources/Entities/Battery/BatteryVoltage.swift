public enum BatteryVoltage: Equatable, Sendable {
    case unknown
    case known(volts: Double)

    public var volts: Double? {
        switch self {
        case .unknown: nil
        case .known(let volts): volts
        }
    }
}
