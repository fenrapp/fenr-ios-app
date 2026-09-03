import BikeDomain
import Foundation

extension BikeBatteryHealthToViewStateMapper {
    func cellMetrics(for analysis: BatteryHealthAnalysis) -> [BatteryHealthMetricViewData] {
        [
            metric("minimum", BatteryHealthText.minimum, cellSummary(analysis.minimumCell)),
            metric("maximum", BatteryHealthText.maximum, cellSummary(analysis.maximumCell)),
            metric(
                "average",
                BatteryHealthText.average,
                analysis.averageCellVoltage.map(formatter.cellVoltage) ?? BatteryHealthText.placeholder
            ),
            metric("delta", BatteryHealthText.delta, millivolts(analysis.cellDeltaVolts))
        ]
    }

    func cellViewData(for analysis: BatteryHealthAnalysis) -> [BatteryCellViewData] {
        analysis.cells.map { cell in
            BatteryCellViewData(
                position: cell.position,
                voltage: formatter.cellVoltage(cell.voltage),
                deviation: formatter.voltageDeviation(volts: cell.deviation),
                condition: condition(cell.condition),
                isBalancing: cell.isBalancing,
                isMinimum: cell.isMinimum,
                isMaximum: cell.isMaximum,
                deviationProgress: min(abs(cell.deviation) / Constants.criticalDeviationVolts, 1),
                deviationMillivolts: cell.deviation * Constants.millivoltsPerVolt
            )
        }
    }

    func distribution(for analysis: BatteryHealthAnalysis) -> BatteryHealthDistributionViewData {
        .init(
            normalCount: analysis.cells.count { $0.condition == .normal },
            attentionCount: analysis.cells.count {
                $0.condition == .belowAverage || $0.condition == .aboveAverage
            },
            criticalCount: analysis.criticalCellCount
        )
    }

    func cellSummary(_ cell: BatteryCellVoltage?) -> String {
        guard let cell else { return BatteryHealthText.placeholder }
        return "#\(cell.position) · \(formatter.cellVoltage(cell.volts))"
    }

    func millivolts(_ volts: Double?) -> String {
        guard let volts else { return BatteryHealthText.placeholder }
        let value = volts * Constants.millivoltsPerVolt
        return "\(value.formatted(.number.precision(.fractionLength(0)))) mV"
    }

    func condition(_ condition: BatteryCellHealthCondition) -> BatteryCellCondition {
        switch condition {
        case .normal: .normal
        case .belowAverage: .belowAverage
        case .aboveAverage: .aboveAverage
        case .critical: .critical
        }
    }
}
