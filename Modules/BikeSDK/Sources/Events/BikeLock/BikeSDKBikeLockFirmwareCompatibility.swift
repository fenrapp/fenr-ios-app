public struct BikeSDKBikeLockFirmwareCompatibility: Equatable, Sendable {
    public let firmware: String
    public let isCompatible: Bool

    public init(firmware: String, isCompatible: Bool) {
        self.firmware = firmware
        self.isCompatible = isCompatible
    }
}
