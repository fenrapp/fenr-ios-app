import BikeDomain
import ChargeControl
import Foundation

@MainActor
public struct BikeBatteryHealthToViewStateMapper {
    private let formatter: BatteryHealthFormatter
    private let analyzer: BatteryHealthAnalyzer

    public init(
        formatter: BatteryHealthFormatter,
        analyzer: BatteryHealthAnalyzer = .init()
    ) {
        self.formatter = formatter
        self.analyzer = analyzer
    }

    public func map(
        health: BikeBatteryHealth,
        captures: [BatteryDataset: BatteryDatasetCapture],
        chargeControl: ChargeControlState = .init(),
        isMonitoring: Bool,
        monitorError: String?
    ) -> BatteryHealthViewState {
        let analysis = analyzer.analyze(health)
        return BatteryHealthViewState(
            summary: [
                metric("soc", "SOC", formatter.percent(health.stateOfCharge.percent)),
                metric("soh", "SOH", formatter.percent(health.stateOfHealth.percent)),
                metric("dcBus", "DC bus", formatter.voltage(health.dcBusVoltage.volts)),
                metric("charge", "Charge", formatter.chargeState(health.chargeState)),
                metric("updated", "Updated", formatter.date(health.lastUpdated))
            ],
            charging: chargingMetrics(for: health),
            packStatus: [
                metric("fault", "BMS fault", health.isBMSFaultActive ? "Active" : "Clear"),
                metric("captured", "Captured datasets", "\(captures.count)/\(BatteryDataset.allCases.count)"),
                metric("cellDelta", "Cell delta", cellDelta(for: analysis))
            ],
            cells: cellViewData(for: analysis),
            temperatures: temperatureViewData(for: health),
            datasets: BatteryDataset.allCases.map { dataset in
            datasetViewData(dataset: dataset, capture: captures[dataset], health: health)
            },
            chargePowerControl: mapChargeControl(chargeControl),
            isMonitoring: isMonitoring,
            monitorError: monitorError
        )
    }

    private func mapChargeControl(_ state: ChargeControlState) -> BatteryHealthChargeControlViewState {
        .init(
            isVisible: state.isVisible,
            isEnabled: state.isEnabled,
            power: .init(
                selected: state.selectedWatts,
                minimum: state.minimumWatts,
                maximum: state.maximumWatts,
                step: state.stepWatts
            ),
            target: .init(
                selected: state.selectedTargetPercent,
                minimum: state.minimumTargetPercent,
                maximum: state.maximumTargetPercent,
                step: state.targetStepPercent
            ),
            chargerText: "\(state.chargerType) charger",
            statusText: state.status,
            statusIsError: state.error != nil,
            errorText: state.error
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
        let status: BatteryHealthStatusViewData
        if isValidated(dataset: dataset, health: health) {
            status = .init(text: BatteryHealthText.validated, emphasis: .positive)
        } else if let capture {
            status = .init(
                text: "\(BatteryHealthText.captured) \(capture.byteCount) B",
                emphasis: .warning
            )
        } else {
            status = .init(text: BatteryHealthText.awaitingSample, emphasis: .neutral)
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

    private func cellDelta(for analysis: BatteryHealthAnalysis) -> String {
        analysis.cellDeltaVolts.map(formatter.cellVoltage) ?? BatteryHealthText.placeholder
    }

    private func cellViewData(for analysis: BatteryHealthAnalysis) -> [BatteryCellViewData] {
        analysis.cells.map { cell in
            BatteryCellViewData(
                position: cell.position,
                voltage: formatter.cellVoltage(cell.voltage),
                deviation: formatter.voltageDeviation(volts: cell.deviation),
                condition: condition(cell.condition),
                isBalancing: cell.isBalancing,
                isMinimum: cell.isMinimum,
                isMaximum: cell.isMaximum
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

    private func condition(_ condition: BatteryCellHealthCondition) -> BatteryCellCondition {
        switch condition {
        case .normal: .normal
        case .belowAverage: .belowAverage
        case .aboveAverage: .aboveAverage
        case .critical: .critical
        }
    }
}
