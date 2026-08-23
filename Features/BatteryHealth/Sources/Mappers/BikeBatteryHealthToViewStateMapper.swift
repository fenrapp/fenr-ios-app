import BikeDomain
import Foundation

@MainActor
public struct BikeBatteryHealthToViewStateMapper {
    private let formatter: BatteryHealthFormatter

    public init(formatter: BatteryHealthFormatter) {
        self.formatter = formatter
    }

    public func map(
        health: BikeBatteryHealth,
        captures: [BatteryDataset: BatteryDatasetCapture],
        isMonitoring: Bool,
        monitorError: String?
    ) -> BatteryHealthViewState {
        BatteryHealthViewState(
            summary: [
                metric("soc", "SOC", formatter.percent(health.stateOfCharge.percent)),
                metric("soh", "SOH", formatter.percent(health.stateOfHealth.percent)),
                metric("dcBus", "DC bus", formatter.voltage(health.dcBusVoltage.volts)),
                metric("charge", "Charge", formatter.chargeState(health.chargeState)),
                metric("updated", "Updated", formatter.date(health.lastUpdated))
            ],
            charging: chargingMetrics(for: health),
            packStatus: [
                metric("fault", "BMS fault", health.isFaultActive ? "Active" : "Clear"),
                metric("captured", "Captured datasets", "\(captures.count)/\(BatteryDataset.allCases.count)"),
                metric("cellDelta", "Cell delta", cellDelta(for: health.cellVoltages))
            ],
            cells: cellViewData(for: health),
            temperatures: temperatureViewData(for: health),
            datasets: BatteryDataset.allCases.map { dataset in
            datasetViewData(dataset: dataset, capture: captures[dataset], health: health)
            },
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
    }

    private func metric(_ id: String, _ title: String, _ value: String) -> BatteryHealthMetricViewData {
        .init(id: id, title: title, value: value)
    }

    private func datasetViewData(
        dataset: BatteryDataset,
        capture: BatteryDatasetCapture?,
        health: BikeBatteryHealth
    ) -> BatteryHealthDatasetViewData {
        let status: BatteryHealthDatasetViewData.Status
        if isValidated(dataset: dataset, health: health) {
            status = .validated(BatteryHealthText.validated)
        } else if let capture {
            status = .captured(
                "\(BatteryHealthText.captured) \(capture.byteCount) B"
            )
        } else {
            status = .awaitingSample
        }
        return .init(id: dataset.rawValue, title: dataset.displayName, status: status)
    }

    private func isValidated(dataset: BatteryDataset, health: BikeBatteryHealth) -> Bool {
        switch dataset {
        case .cellVoltages: !health.cellVoltages.isEmpty
        case .temperatures: !health.temperatures.isEmpty
        case .balancing: !health.cellVoltages.isEmpty
        case .bmsStatus, .dcBus, .signals: false
        case .charger: health.chargingStatus != nil
        }
    }

    private func cellDelta(for cells: [BatteryCellVoltage]) -> String {
        guard let minimum = cells.map(\.volts).min(), let maximum = cells.map(\.volts).max() else {
            return BatteryHealthText.placeholder
        }
        return formatter.cellVoltage(maximum - minimum)
    }

    private func cellViewData(for health: BikeBatteryHealth) -> [BatteryCellViewData] {
        let voltages = health.cellVoltages.map(\.volts)
        guard let minimum = voltages.min(), let maximum = voltages.max() else { return [] }
        let average = voltages.reduce(0, +) / Double(voltages.count)
        return health.cellVoltages.map { cell in
            BatteryCellViewData(
                position: cell.position,
                voltage: formatter.cellVoltage(cell.volts),
                deviation: formatter.voltageDeviation(volts: cell.volts - average),
                condition: condition(for: cell.volts, average: average),
                isBalancing: health.balancingCellIndexes.contains(cell.position - 1),
                isMinimum: cell.volts == minimum,
                isMaximum: cell.volts == maximum
            )
        }
    }

    private func temperatureViewData(for health: BikeBatteryHealth) -> [BatteryTemperatureViewData] {
        health.temperatures.map {
            BatteryTemperatureViewData(position: $0.position, value: formatter.temperature(celsius: $0.celsius))
        }
    }

    private func chargingMetrics(for health: BikeBatteryHealth) -> [BatteryHealthMetricViewData] {
        guard health.chargeState == .charging, let charging = health.chargingStatus else { return [] }

        let outputPower = health.dcBusVoltage.volts.map { $0 * charging.reportedCurrentAmperes }
        var metrics = [
            metric("chargeCurrent", "Charge current", formatter.current(amperes: charging.reportedCurrentAmperes)),
            metric("chargeRequest", "Current target", formatter.current(amperes: charging.requestedCurrentAmperes)),
            metric("chargePowerLimit", "Power limit", formatter.power(watts: charging.maximumPowerWatts)),
            metric("chargeCurrentLimit", "Current limit", formatter.current(amperes: charging.maximumCurrentAmperes)),
            metric("chargeCellTarget", "Cell target", formatter.cellVoltage(charging.targetCellVoltageVolts)),
            metric("chargeSocLimit", "SOC limit", formatter.percent(charging.maximumStateOfChargePercent))
        ]
        if let outputPower {
            metrics.insert(metric("chargePower", "Output power", formatter.power(watts: outputPower)), at: 0)
        }
        return metrics
    }

    private func condition(for voltage: Double, average: Double) -> BatteryCellCondition {
        let deviation = voltage - average
        if voltage <= Constants.criticalVoltage || abs(deviation) >= Constants.criticalDeviation {
            return .critical
        }
        if deviation <= -Constants.warningDeviation {
            return .belowAverage
        }
        if deviation >= Constants.warningDeviation {
            return .aboveAverage
        }
        return .normal
    }

    private enum Constants {
        static let criticalVoltage = 3.0
        static let warningDeviation = 0.02
        static let criticalDeviation = 0.05
    }
}
