import BikeDomain

public struct ChargeControlLogStore {
    public private(set) var lines: [String] = []

    public init() {}

    mutating func appendTelemetry(charging: BikeChargingStatus) {
        let type = "\(charging.chargerType.technicalLogName) raw=\(charging.chargerType.rawValue)"
        let line = "5001 type=\(type) "
            + "maximumPower=\(Int(charging.maximumPowerWatts.rounded())) W "
            + "maxSoc=\(charging.maximumStateOfChargePercent)%"
        guard lines.last != line else { return }
        append(line)
    }

    mutating func append(_ line: String) {
        lines.append(line)
        if lines.count > ChargeControlConstants.maximumLogLines {
            lines.removeFirst(lines.count - ChargeControlConstants.maximumLogLines)
        }
    }
}
