import BikeDomain

public struct ChargeControlLogStore {
    public private(set) var lines: [String] = []

    private let isRecording: @Sendable () -> Bool

    public init(isRecording: @escaping @Sendable () -> Bool) {
        self.isRecording = isRecording
    }

    mutating func appendTelemetry(charging: BikeChargingStatus) {
        guard isRecording() else { return }
        let type = "\(charging.chargerType.technicalLogName) raw=\(charging.chargerType.rawValue)"
        let line = "5001 type=\(type) "
            + "maximumPower=\(Int(charging.maximumPowerWatts.rounded())) W "
            + "maxSoc=\(charging.maximumStateOfChargePercent)%"
        guard lines.last != line else { return }
        append(line)
    }

    mutating func append(_ line: @autoclosure () -> String) {
        guard isRecording() else { return }
        lines.append(line())
        if lines.count > ChargeControlConstants.maximumLogLines {
            lines.removeFirst(lines.count - ChargeControlConstants.maximumLogLines)
        }
    }
}
