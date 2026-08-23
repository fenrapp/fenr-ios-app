public struct StarkBatteryTemperaturesPayload: StarkPayload {
    public let celsius: [Double]
    public let validSensorMask: Int
    public let usedSensorCount: Int

    public init(celsius: [Double], validSensorMask: Int, usedSensorCount: Int) {
        self.celsius = celsius
        self.validSensorMask = validSensorMask
        self.usedSensorCount = usedSensorCount
    }
}
