import BikeDomain
import ChargeControl
import Foundation

extension BikeBatteryHealthToViewStateMapper {
    func chargingMetrics(for health: BikeBatteryHealth) -> [BatteryHealthMetricViewData] {
        guard let charging = health.chargingStatus else {
            return []
        }
        let outputPower = health.dcBusVoltage.volts.map { $0 * charging.reportedCurrentAmperes }
        var metrics = [
            metric(
                "chargeState",
                String(localized: .batteryHealthMetricState),
                formatter.chargeState(health.chargeState)
            ),
            metric(
                "charger",
                String(localized: .batteryHealthMetricCharger),
                chargerText(for: charging.chargerType)
            ),
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
                    String(localized: .batteryHealthMetricPower),
                    formatter.power(watts: outputPower)
                ),
                at: 2
            )
        }
        return metrics
    }

    func mapChargeControl(_ state: ChargeControlState) -> BatteryHealthChargeControlViewState {
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

    func chargerText(for type: BikeChargerType?) -> String {
        switch type {
        case .standard?: String(localized: .batteryHealthChargerStandard)
        case .fast?: String(localized: .batteryHealthChargerFast)
        case .backpack?: String(localized: .batteryHealthChargerBackpack)
        case .unknown(let rawValue)?: String(localized: .batteryHealthChargerUnknownValue(rawValue))
        case nil: String(localized: .batteryHealthChargerUnknown)
        }
    }

    func statusText(for status: ChargeControlStatus) -> String {
        switch status {
        case .unavailable: String(localized: .batteryHealthChargeControlStatusUnavailable)
        case .preparing: String(localized: .batteryHealthChargeControlStatusPreparing)
        case .ready: String(localized: .batteryHealthChargeControlStatusReady)
        case .updating: String(localized: .batteryHealthChargeControlStatusUpdating)
        case .unsupportedFirmware: String(localized: .batteryHealthChargeControlStatusUnsupportedFirmware)
        case .noOpGuardFailed: String(localized: .batteryHealthChargeControlStatusNoOpGuardFailed)
        case .writing(let value): writingStatusText(value)
        case .confirming(let value): confirmingStatusText(value)
        case .confirmed(let value): confirmedStatusText(value)
        case .updateFailed: String(localized: .batteryHealthChargeControlStatusUpdateFailed)
        }
    }

    private func writingStatusText(_ value: ChargeControlSettingValue) -> String {
        switch value {
        case .powerWatts(let watts): String(localized: .batteryHealthChargeControlStatusWritingPower(watts))
        case .targetPercent(let percent): String(localized: .batteryHealthChargeControlStatusWritingTarget(percent))
        }
    }

    private func confirmingStatusText(_ value: ChargeControlSettingValue) -> String {
        switch value {
        case .powerWatts(let watts): String(localized: .batteryHealthChargeControlStatusConfirmingPower(watts))
        case .targetPercent(let percent): String(localized: .batteryHealthChargeControlStatusConfirmingTarget(percent))
        }
    }

    private func confirmedStatusText(_ value: ChargeControlSettingValue) -> String {
        switch value {
        case .powerWatts(let watts): String(localized: .batteryHealthChargeControlStatusConfirmedPower(watts))
        case .targetPercent(let percent): String(localized: .batteryHealthChargeControlStatusConfirmedTarget(percent))
        }
    }

    func failureText(_ failure: ChargeControlFailure) -> String {
        switch failure {
        case .incompatibleFirmware: String(localized: .batteryHealthChargeControlErrorIncompatibleFirmware)
        case .noOpValidationFailed: String(localized: .batteryHealthChargeControlErrorNoOpValidation)
        case .preparationFailed: String(localized: .batteryHealthChargeControlErrorPreparation)
        case .writeFailed: String(localized: .batteryHealthChargeControlErrorWrite)
        case .confirmationTimedOut: String(localized: .batteryHealthChargeControlErrorConfirmation)
        }
    }
}
