public struct StarkIMUPayload: StarkPayload {
    public let accelerationXRaw: Int
    public let accelerationYRaw: Int
    public let accelerationZRaw: Int
    public let gyroscopeXRaw: Int
    public let gyroscopeYRaw: Int
    public let gyroscopeZRaw: Int

    public init(
        accelerationXRaw: Int,
        accelerationYRaw: Int,
        accelerationZRaw: Int,
        gyroscopeXRaw: Int,
        gyroscopeYRaw: Int,
        gyroscopeZRaw: Int
    ) {
        self.accelerationXRaw = accelerationXRaw
        self.accelerationYRaw = accelerationYRaw
        self.accelerationZRaw = accelerationZRaw
        self.gyroscopeXRaw = gyroscopeXRaw
        self.gyroscopeYRaw = gyroscopeYRaw
        self.gyroscopeZRaw = gyroscopeZRaw
    }
}
