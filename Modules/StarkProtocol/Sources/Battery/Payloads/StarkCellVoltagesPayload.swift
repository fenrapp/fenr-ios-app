public struct StarkCellVoltagesPayload: StarkPayload {
    public let volts: [Double]

    public init(volts: [Double]) {
        self.volts = volts
    }
}
