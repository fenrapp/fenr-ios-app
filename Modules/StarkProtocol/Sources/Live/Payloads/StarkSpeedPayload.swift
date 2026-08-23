public struct StarkSpeedPayload: StarkPayload {
    public let speedKmh: Double
    public let speedKmhX10: Int
    public let motorRPM: Int

    public init(speedKmh: Double, speedKmhX10: Int, motorRPM: Int) {
        self.speedKmh = speedKmh
        self.speedKmhX10 = speedKmhX10
        self.motorRPM = motorRPM
    }
}
