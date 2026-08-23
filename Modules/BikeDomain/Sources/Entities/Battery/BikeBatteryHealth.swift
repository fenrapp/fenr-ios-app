import Foundation

public struct BikeBatteryHealth: Equatable, Sendable {
    public var stateOfCharge: BatteryLevel
    public var stateOfHealth: HealthLevel
    public var dcBusVoltage: BatteryVoltage
    public var chargeState: BatteryChargeState
    public var isFaultActive: Bool
    public var cellVoltages: [BatteryCellVoltage]
    public var balancingCellIndexes: Set<Int>
    public var temperatures: [BatteryTemperature]
    public var chargingStatus: BikeChargingStatus?
    public var lastUpdated: Date?

    public init(
        stateOfCharge: BatteryLevel = .unknown,
        stateOfHealth: HealthLevel = .unknown,
        dcBusVoltage: BatteryVoltage = .unknown,
        chargeState: BatteryChargeState = .unknown,
        isFaultActive: Bool = false,
        cellVoltages: [BatteryCellVoltage] = [],
        balancingCellIndexes: Set<Int> = [],
        temperatures: [BatteryTemperature] = [],
        chargingStatus: BikeChargingStatus? = nil,
        lastUpdated: Date? = nil
    ) {
        self.stateOfCharge = stateOfCharge
        self.stateOfHealth = stateOfHealth
        self.dcBusVoltage = dcBusVoltage
        self.chargeState = chargeState
        self.isFaultActive = isFaultActive
        self.cellVoltages = cellVoltages
        self.balancingCellIndexes = balancingCellIndexes
        self.temperatures = temperatures
        self.chargingStatus = chargingStatus
        self.lastUpdated = lastUpdated
    }
}
