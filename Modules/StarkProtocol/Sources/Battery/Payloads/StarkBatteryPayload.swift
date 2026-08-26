public struct StarkBatteryPayload: StarkPayload {
    public let stateOfChargePercent: Int
    public let stateOfHealthPercent: Int?
    public let dcBusRaw: Int?

    public init(stateOfChargePercent: Int, stateOfHealthPercent: Int?, dcBusRaw: Int?) {
        self.stateOfChargePercent = stateOfChargePercent
        self.stateOfHealthPercent = stateOfHealthPercent
        self.dcBusRaw = dcBusRaw
    }

    public var dcBusVolts: Double? {
        dcBusRaw.map { Double($0) / StarkBatteryElectricalScale.dcBus }
    }
}
