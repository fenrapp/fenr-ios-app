public struct DashboardSystemHealthViewData: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case scanning
        case healthy
        case lowBattery
        case attention
        case critical
        case unavailable
    }

    public enum CellCondition: Equatable, Sendable {
        case normal
        case belowAverage
        case aboveAverage
        case critical
    }

    public struct Cell: Equatable, Sendable {
        public let position: Int
        public let voltageText: String
        public let deviationText: String
        public let condition: CellCondition
        public let isBalancing: Bool

        public init(
            position: Int,
            voltageText: String,
            deviationText: String,
            condition: CellCondition,
            isBalancing: Bool
        ) {
            self.position = position
            self.voltageText = voltageText
            self.deviationText = deviationText
            self.condition = condition
            self.isBalancing = isBalancing
        }
    }

    public struct ThermalRange: Equatable, Sendable {
        public let minimumCelsius: Double
        public let averageCelsius: Double
        public let maximumCelsius: Double
        public let minimumText: String
        public let averageText: String
        public let maximumText: String

        public init(
            minimumCelsius: Double,
            averageCelsius: Double,
            maximumCelsius: Double,
            minimumText: String,
            averageText: String,
            maximumText: String
        ) {
            self.minimumCelsius = minimumCelsius
            self.averageCelsius = averageCelsius
            self.maximumCelsius = maximumCelsius
            self.minimumText = minimumText
            self.averageText = averageText
            self.maximumText = maximumText
        }
    }

    public let status: Status
    public let statusText: String
    public let statusDetail: String
    public let stateOfHealthText: String
    public let stateOfHealthProgress: Double
    public let cellDeltaText: String
    public let dcBusVoltageText: String
    public let batteryTemperatureText: String
    public let inverterTemperatureText: String
    public let criticalCellCount: Int
    public let attentionCellCount: Int
    public let balancingCellCount: Int
    public let cells: [Cell]
    public let minimumCellText: String
    public let maximumCellText: String
    public let batteryThermalRange: ThermalRange?
    public let inverterThermalRange: ThermalRange?

    public init(
        status: Status = .scanning,
        statusText: String? = nil,
        statusDetail: String = "",
        stateOfHealthText: String = "—",
        stateOfHealthProgress: Double = .zero,
        cellDeltaText: String = "—",
        dcBusVoltageText: String = "—",
        batteryTemperatureText: String = "—",
        inverterTemperatureText: String = "—",
        criticalCellCount: Int = .zero,
        attentionCellCount: Int = .zero,
        balancingCellCount: Int = .zero,
        cells: [Cell] = [],
        minimumCellText: String = "—",
        maximumCellText: String = "—",
        batteryThermalRange: ThermalRange? = nil,
        inverterThermalRange: ThermalRange? = nil
    ) {
        self.status = status
        self.statusText = statusText ?? rideDashboardLocalized(.rideDashboardSystemHealthStatusScanning)
        self.statusDetail = statusDetail
        self.stateOfHealthText = stateOfHealthText
        self.stateOfHealthProgress = stateOfHealthProgress
        self.cellDeltaText = cellDeltaText
        self.dcBusVoltageText = dcBusVoltageText
        self.batteryTemperatureText = batteryTemperatureText
        self.inverterTemperatureText = inverterTemperatureText
        self.criticalCellCount = criticalCellCount
        self.attentionCellCount = attentionCellCount
        self.balancingCellCount = balancingCellCount
        self.cells = cells
        self.minimumCellText = minimumCellText
        self.maximumCellText = maximumCellText
        self.batteryThermalRange = batteryThermalRange
        self.inverterThermalRange = inverterThermalRange
    }
}
