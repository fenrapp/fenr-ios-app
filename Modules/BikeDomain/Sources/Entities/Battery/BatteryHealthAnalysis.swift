public enum BatteryHealthSeverity: Int, Equatable, Sendable {
    case unknown
    case healthy
    case attention
    case critical
}

public enum BatteryCellHealthCondition: Equatable, Sendable {
    case normal
    case belowAverage
    case aboveAverage
    case critical
}

public struct BatteryCellHealthAssessment: Equatable, Identifiable, Sendable {
    public let position: Int
    public let voltage: Double
    public let deviation: Double
    public let condition: BatteryCellHealthCondition
    public let isBalancing: Bool
    public let isMinimum: Bool
    public let isMaximum: Bool

    public var id: Int { position }

    public init(
        position: Int,
        voltage: Double,
        deviation: Double,
        condition: BatteryCellHealthCondition,
        isBalancing: Bool,
        isMinimum: Bool,
        isMaximum: Bool
    ) {
        self.position = position
        self.voltage = voltage
        self.deviation = deviation
        self.condition = condition
        self.isBalancing = isBalancing
        self.isMinimum = isMinimum
        self.isMaximum = isMaximum
    }
}

public struct BatteryTemperatureStatistics: Equatable, Sendable {
    public let minimumCelsius: Double
    public let averageCelsius: Double
    public let maximumCelsius: Double

    public init(minimumCelsius: Double, averageCelsius: Double, maximumCelsius: Double) {
        self.minimumCelsius = minimumCelsius
        self.averageCelsius = averageCelsius
        self.maximumCelsius = maximumCelsius
    }
}

public struct BatteryHealthAnalysis: Equatable, Sendable {
    public let severity: BatteryHealthSeverity
    public let stateOfChargePercent: Int?
    public let stateOfHealthPercent: Int?
    public let cellDeltaVolts: Double?
    public let averageCellVoltage: Double?
    public let minimumCell: BatteryCellVoltage?
    public let maximumCell: BatteryCellVoltage?
    public let cells: [BatteryCellHealthAssessment]
    public let criticalCellCount: Int
    public let attentionCellCount: Int
    public let balancingCellCount: Int
    public let batteryTemperatures: BatteryTemperatureStatistics?
    public let isBMSFaultActive: Bool
    public let isLowBattery: Bool

    public init(
        severity: BatteryHealthSeverity,
        stateOfChargePercent: Int?,
        stateOfHealthPercent: Int?,
        cellDeltaVolts: Double?,
        averageCellVoltage: Double?,
        minimumCell: BatteryCellVoltage?,
        maximumCell: BatteryCellVoltage?,
        cells: [BatteryCellHealthAssessment],
        criticalCellCount: Int,
        attentionCellCount: Int,
        balancingCellCount: Int,
        batteryTemperatures: BatteryTemperatureStatistics?,
        isBMSFaultActive: Bool,
        isLowBattery: Bool
    ) {
        self.severity = severity
        self.stateOfChargePercent = stateOfChargePercent
        self.stateOfHealthPercent = stateOfHealthPercent
        self.cellDeltaVolts = cellDeltaVolts
        self.averageCellVoltage = averageCellVoltage
        self.minimumCell = minimumCell
        self.maximumCell = maximumCell
        self.cells = cells
        self.criticalCellCount = criticalCellCount
        self.attentionCellCount = attentionCellCount
        self.balancingCellCount = balancingCellCount
        self.batteryTemperatures = batteryTemperatures
        self.isBMSFaultActive = isBMSFaultActive
        self.isLowBattery = isLowBattery
    }
}
