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
                metric(
                    "soc",
                    String(localized: .batteryHealthMetricSoc),
                    formatter.percent(health.stateOfCharge.percent)
                ),
                metric(
                    "soh",
                    String(localized: .batteryHealthMetricSoh),
                    formatter.percent(health.stateOfHealth.percent)
                ),
                metric(
                    "dcBus",
                    String(localized: .batteryHealthMetricDcBus),
                    formatter.voltage(health.dcBusVoltage.volts)
                ),
                metric(
                    "charge",
                    String(localized: .batteryHealthMetricCharge),
                    formatter.chargeState(health.chargeState)
                ),
                metric("updated", String(localized: .batteryHealthMetricUpdated), formatter.date(health.lastUpdated))
            ],
            charging: chargingMetrics(for: health),
            packStatus: [
                metric(
                    "fault",
                    String(localized: .batteryHealthMetricBmsFault),
                    String(localized: health.isBMSFaultActive ? .batteryHealthStatusActive : .batteryHealthStatusClear)
                ),
                metric(
                    "captured",
                    String(localized: .batteryHealthMetricCapturedDatasets),
                    "\(captures.count)/\(BatteryDataset.allCases.count)"
                ),
                metric("cellDelta", String(localized: .batteryHealthMetricCellDelta), cellDelta(for: analysis))
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
            isEnabled: state.canAcceptInput,
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
            chargerText: chargerText(for: state.chargerType),
            statusText: statusText(for: state.status),
            statusIsError: state.failure != nil,
            errorText: state.failure.map(failureText)
        )
    }

    private func chargerText(for type: BikeChargerType?) -> String {
        switch type {
        case .standard?: String(localized: .batteryHealthChargerStandard)
        case .fast?: String(localized: .batteryHealthChargerFast)
        case .backpack?: String(localized: .batteryHealthChargerBackpack)
        case .unknown(let rawValue)?: String(localized: .batteryHealthChargerUnknownValue(rawValue))
        case nil: String(localized: .batteryHealthChargerUnknown)
        }
    }

    private func statusText(for status: ChargeControlStatus) -> String {
        switch status {
        case .unavailable: String(localized: .batteryHealthChargeControlStatusUnavailable)
        case .preparing: String(localized: .batteryHealthChargeControlStatusPreparing)
        case .ready: String(localized: .batteryHealthChargeControlStatusReady)
        case .updating: String(localized: .batteryHealthChargeControlStatusUpdating)
        case .unsupportedFirmware: String(localized: .batteryHealthChargeControlStatusUnsupportedFirmware)
        case .noOpGuardFailed: String(localized: .batteryHealthChargeControlStatusNoOpGuardFailed)
        case .writing(let value): writingText(value)
        case .confirming(let value): confirmingText(value)
        case .confirmed(let value): confirmedText(value)
        case .updateFailed: String(localized: .batteryHealthChargeControlStatusUpdateFailed)
        }
    }

    private func writingText(_ value: ChargeControlSettingValue) -> String {
        switch value {
        case .powerWatts(let watts): String(localized: .batteryHealthChargeControlStatusWritingPower(watts))
        case .targetPercent(let percent): String(localized: .batteryHealthChargeControlStatusWritingTarget(percent))
        }
    }

    private func confirmingText(_ value: ChargeControlSettingValue) -> String {
        switch value {
        case .powerWatts(let watts): String(localized: .batteryHealthChargeControlStatusConfirmingPower(watts))
        case .targetPercent(let percent): String(localized: .batteryHealthChargeControlStatusConfirmingTarget(percent))
        }
    }

    private func confirmedText(_ value: ChargeControlSettingValue) -> String {
        switch value {
        case .powerWatts(let watts): String(localized: .batteryHealthChargeControlStatusConfirmedPower(watts))
        case .targetPercent(let percent): String(localized: .batteryHealthChargeControlStatusConfirmedTarget(percent))
        }
    }

    private func failureText(_ failure: ChargeControlFailure) -> String {
        switch failure {
        case .incompatibleFirmware: String(localized: .batteryHealthChargeControlErrorIncompatibleFirmware)
        case .noOpValidationFailed: String(localized: .batteryHealthChargeControlErrorNoOpValidation)
        case .preparationFailed: String(localized: .batteryHealthChargeControlErrorPreparation)
        case .writeFailed: String(localized: .batteryHealthChargeControlErrorWrite)
        case .confirmationTimedOut: String(localized: .batteryHealthChargeControlErrorConfirmation)
        }
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
                text: String(localized: .batteryHealthDatasetCapturedBytes(capture.byteCount)),
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
            metric(
                "chargeCurrent",
                String(localized: .batteryHealthMetricChargeCurrent),
                formatter.current(amperes: charging.reportedCurrentAmperes)
            ),
            metric(
                "chargeRequest",
                String(localized: .batteryHealthMetricCurrentTarget),
                formatter.current(amperes: charging.requestedCurrentAmperes)
            ),
            metric(
                "chargePowerLimit",
                String(localized: .batteryHealthMetricPowerLimit),
                formatter.power(watts: charging.maximumPowerWatts)
            ),
            metric(
                "chargeCurrentLimit",
                String(localized: .batteryHealthMetricCurrentLimit),
                formatter.current(amperes: charging.maximumCurrentAmperes)
            ),
            metric(
                "chargeCellTarget",
                String(localized: .batteryHealthMetricCellTarget),
                formatter.cellVoltage(charging.targetCellVoltageVolts)
            ),
            metric(
                "chargeSocLimit",
                String(localized: .batteryHealthMetricSocLimit),
                formatter.percent(charging.maximumStateOfChargePercent)
            )
        ]
        if let outputPower {
            metrics.insert(
                metric(
                    "chargePower",
                    String(localized: .batteryHealthMetricOutputPower),
                    formatter.power(watts: outputPower)
                ),
                at: 0
            )
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
