import BikeDomain

public struct BatteryHealthChargeControlLogStore {
    private(set) var lines: [String] = []

    public init() {}

    mutating func appendTelemetry(charging: BikeChargingStatus) -> Bool {
        let type = "\(charging.chargerType.displayName) raw=\(charging.chargerType.rawValue)"
        let line = "5001 type=\(type) "
            + "maximumPower=\(Int(charging.maximumPowerWatts.rounded())) W "
            + "maxSoc=\(charging.maximumStateOfChargePercent)%"
        guard lines.last != line else { return false }
        append(line)
        return true
    }

    mutating func append(_ line: String) {
        lines.append(line)
        if lines.count > BatteryHealthChargeControlConstants.maximumLogLines {
            lines.removeFirst(lines.count - BatteryHealthChargeControlConstants.maximumLogLines)
        }
    }
}
