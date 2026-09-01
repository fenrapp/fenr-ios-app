public struct BatteryHealthAnalyzer: Sendable {
    public init() {}

    public func analyze(_ health: BikeBatteryHealth) -> BatteryHealthAnalysis {
        let validCells = health.cellVoltages.filter { $0.volts.isFinite }
        let voltages = validCells.map(\.volts)
        let average = voltages.isEmpty ? nil : voltages.reduce(.zero, +) / Double(voltages.count)
        let minimumCell = validCells.min { $0.volts < $1.volts }
        let maximumCell = validCells.max { $0.volts < $1.volts }
        let delta = minMaxDelta(minimum: minimumCell?.volts, maximum: maximumCell?.volts)
        let isLowBattery = health.stateOfCharge.percent.map {
            $0 <= Constants.lowBatteryStateOfChargePercent
        } ?? false
        let cells = assessedCells(
            validCells,
            average: average,
            balancingIndexes: health.balancingCellIndexes,
            suppressUniformLowVoltage: isLowBattery
        )
        let temperatures = temperatureStatistics(health.temperatures)
        let severity = overallSeverity(
            health: health,
            hasCells: !cells.isEmpty,
            delta: delta,
            cells: cells,
            temperatures: temperatures
        )
        return BatteryHealthAnalysis(
            severity: severity,
            stateOfChargePercent: health.stateOfCharge.percent,
            stateOfHealthPercent: health.stateOfHealth.percent,
            cellDeltaVolts: delta,
            averageCellVoltage: average,
            minimumCell: minimumCell,
            maximumCell: maximumCell,
            cells: cells,
            criticalCellCount: cells.count { $0.condition == .critical },
            attentionCellCount: cells.count { $0.condition == .belowAverage || $0.condition == .aboveAverage },
            balancingCellCount: cells.count { $0.isBalancing },
            batteryTemperatures: temperatures,
            isBMSFaultActive: health.isBMSFaultActive,
            isLowBattery: isLowBattery
        )
    }
}

private extension BatteryHealthAnalyzer {
    func assessedCells(
        _ cells: [BatteryCellVoltage],
        average: Double?,
        balancingIndexes: Set<Int>,
        suppressUniformLowVoltage: Bool
    ) -> [BatteryCellHealthAssessment] {
        guard let average else { return [] }
        let minimum = cells.min { $0.volts < $1.volts }?.volts
        let maximum = cells.max { $0.volts < $1.volts }?.volts
        return cells.map { cell in
            let deviation = cell.volts - average
            return BatteryCellHealthAssessment(
                position: cell.position,
                voltage: cell.volts,
                deviation: deviation,
                condition: cellCondition(
                    voltage: cell.volts,
                    deviation: deviation,
                    suppressUniformLowVoltage: suppressUniformLowVoltage
                ),
                isBalancing: balancingIndexes.contains(cell.position - Constants.firstCellPosition),
                isMinimum: cell.volts == minimum,
                isMaximum: cell.volts == maximum
            )
        }
    }

    func cellCondition(
        voltage: Double,
        deviation: Double,
        suppressUniformLowVoltage: Bool
    ) -> BatteryCellHealthCondition {
        if meetsThreshold(abs(deviation), Constants.criticalCellDeviation)
            || (!suppressUniformLowVoltage && voltage <= Constants.criticalCellVoltage) {
            return .critical
        }
        if meetsThreshold(-deviation, Constants.attentionCellDeviation) { return .belowAverage }
        if meetsThreshold(deviation, Constants.attentionCellDeviation) { return .aboveAverage }
        return .normal
    }

    func overallSeverity(
        health: BikeBatteryHealth,
        hasCells: Bool,
        delta: Double?,
        cells: [BatteryCellHealthAssessment],
        temperatures: BatteryTemperatureStatistics?
    ) -> BatteryHealthSeverity {
        var severity: BatteryHealthSeverity = health.isBMSFaultActive ? .critical : .unknown
        severity = max(severity, stateOfHealthSeverity(health.stateOfHealth.percent))
        severity = max(severity, cellDeltaSeverity(delta))
        severity = max(severity, cellSeverity(cells))
        severity = max(severity, temperatureSeverity(temperatures))
        if !hasCells, severity == .healthy { return .unknown }
        return severity
    }

    func stateOfHealthSeverity(_ percent: Int?) -> BatteryHealthSeverity {
        guard let percent else { return .unknown }
        return switch percent {
        case ..<Constants.criticalStateOfHealthPercent: .critical
        case ..<Constants.healthyStateOfHealthPercent: .attention
        default: .healthy
        }
    }

    func cellDeltaSeverity(_ delta: Double?) -> BatteryHealthSeverity {
        guard let delta else { return .unknown }
        if meetsThreshold(delta, Constants.criticalCellDelta) { return .critical }
        if meetsThreshold(delta, Constants.attentionCellDelta) { return .attention }
        return .healthy
    }

    func cellSeverity(_ cells: [BatteryCellHealthAssessment]) -> BatteryHealthSeverity {
        if cells.contains(where: { $0.condition == .critical }) { return .critical }
        if cells.contains(where: { $0.condition == .belowAverage || $0.condition == .aboveAverage }) {
            return .attention
        }
        return cells.isEmpty ? .unknown : .healthy
    }

    func temperatureSeverity(_ statistics: BatteryTemperatureStatistics?) -> BatteryHealthSeverity {
        guard let statistics else { return .unknown }
        if statistics.minimumCelsius < Constants.minimumBatteryTemperature
            || statistics.maximumCelsius >= Constants.criticalBatteryTemperature {
            return .critical
        }
        if statistics.minimumCelsius < Constants.lowBatteryTemperatureWarning
            || statistics.maximumCelsius >= Constants.highBatteryTemperatureWarning {
            return .attention
        }
        return .healthy
    }

    func temperatureStatistics(_ temperatures: [BatteryTemperature]) -> BatteryTemperatureStatistics? {
        let values = temperatures.map(\.celsius).filter(\.isFinite)
        guard let minimum = values.min(), let maximum = values.max() else { return nil }
        return .init(
            minimumCelsius: minimum,
            averageCelsius: values.reduce(.zero, +) / Double(values.count),
            maximumCelsius: maximum
        )
    }

    func minMaxDelta(minimum: Double?, maximum: Double?) -> Double? {
        guard let minimum, let maximum else { return nil }
        return maximum - minimum
    }

    func meetsThreshold(_ value: Double, _ threshold: Double) -> Bool {
        value >= threshold - Constants.comparisonTolerance
    }

    func max(_ lhs: BatteryHealthSeverity, _ rhs: BatteryHealthSeverity) -> BatteryHealthSeverity {
        lhs.rawValue >= rhs.rawValue ? lhs : rhs
    }

    enum Constants {
        static let firstCellPosition = 1
        static let lowBatteryStateOfChargePercent = 20
        static let healthyStateOfHealthPercent = 80
        static let criticalStateOfHealthPercent = 70
        static let criticalCellVoltage = 3.0
        static let attentionCellDeviation = 0.020
        static let criticalCellDeviation = 0.050
        static let attentionCellDelta = 0.020
        static let criticalCellDelta = 0.050
        static let minimumBatteryTemperature = 4.0
        static let lowBatteryTemperatureWarning = 10.0
        static let highBatteryTemperatureWarning = 50.0
        static let criticalBatteryTemperature = 60.0
        static let comparisonTolerance = 0.000_000_001
    }
}
