public struct DashboardDeviceBatterySnapshot: Equatable, Sendable {
    public let level: Double?
    public let isCharging: Bool

    public init(level: Double?, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }
}
