import Foundation

public struct BikeBatteryHealth: Equatable, Sendable {
    public var stateOfCharge: BatteryLevel
    public var stateOfHealth: HealthLevel
    public var dcBusVoltage: BatteryVoltage
    public var chargeState: BatteryChargeState
    public var positiveBMSFaultBits: UInt32
    public var negativeBMSFaultBits: UInt32
    public var cellVoltages: [BatteryCellVoltage]
    public var balancingCellIndexes: Set<Int>
    public var temperatures: [BatteryTemperature]
    public var chargingStatus: BikeChargingStatus?
    public var lastUpdated: Date?
    public var isVehicleFaultActive: Bool

    public var isBMSFaultActive: Bool {
        positiveBMSFaultBits != 0 || negativeBMSFaultBits != 0
    }

    public var isFaultActive: Bool {
        get {
            isVehicleFaultActive || isBMSFaultActive
        }
        set {
            isVehicleFaultActive = newValue
        }
    }

    public init(
        stateOfCharge: BatteryLevel = .unknown,
        stateOfHealth: HealthLevel = .unknown,
        dcBusVoltage: BatteryVoltage = .unknown,
        chargeState: BatteryChargeState = .unknown,
        isFaultActive: Bool = false,
        positiveBMSFaultBits: UInt32 = 0,
        negativeBMSFaultBits: UInt32 = 0,
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
        self.positiveBMSFaultBits = positiveBMSFaultBits
        self.negativeBMSFaultBits = negativeBMSFaultBits
        self.cellVoltages = cellVoltages
        self.balancingCellIndexes = balancingCellIndexes
        self.temperatures = temperatures
        self.chargingStatus = chargingStatus
        self.lastUpdated = lastUpdated
        self.isVehicleFaultActive = isFaultActive
    }
}
