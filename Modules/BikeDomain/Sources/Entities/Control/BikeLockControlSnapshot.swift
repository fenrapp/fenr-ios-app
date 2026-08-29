public struct BikeLockControlSnapshot: Equatable, Sendable {
    public let vcuFirmware: String
    public let isLocked: Bool
    public let didPassNoOpWrite: Bool

    public init(vcuFirmware: String, isLocked: Bool, didPassNoOpWrite: Bool) {
        self.vcuFirmware = vcuFirmware
        self.isLocked = isLocked
        self.didPassNoOpWrite = didPassNoOpWrite
    }
}
