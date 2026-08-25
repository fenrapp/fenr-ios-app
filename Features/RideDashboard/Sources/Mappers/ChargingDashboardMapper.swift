import BikeDomain
import ChargeControl
import Foundation
import MeasurementPresentation
import SettingsDomain

public struct ChargingDashboardMapper: Sendable {
    private let measurementMapper: RideDashboardMeasurementMapper
    private let timeRemainingFormatStyle: Duration.UnitsFormatStyle
    private let batteryPackCapacity: BatteryPackCapacity

    public init(
        measurementMapper: RideDashboardMeasurementMapper,
        timeRemainingFormatStyle: Duration.UnitsFormatStyle,
        batteryPackCapacity: BatteryPackCapacity
    ) {
        self.measurementMapper = measurementMapper
        self.timeRemainingFormatStyle = timeRemainingFormatStyle
        self.batteryPackCapacity = batteryPackCapacity
    }

    public func map(
        telemetry: BikeTelemetry,
        batteryHealth: BikeBatteryHealth,
        chargeControl: ChargeControlState = .init()
    ) -> ChargingDashboardViewState {
        let status = batteryHealth.chargingStatus
        let batteryTemperature = averageBatteryTemperature(from: batteryHealth.temperatures)
        let targetPercent = status.map {
            chargeControl.isVisible
                ? Int(chargeControl.selectedTargetPercent.rounded())
                : $0.maximumStateOfChargePercent
        }
        let batteryPercent = telemetry.batteryLevel.percent
        let isBalancingAtFullCharge = batteryPercent == Constants.fullChargePercent
            && !batteryHealth.balancingCellIndexes.isEmpty
        let estimatedTimeRemaining = estimatedTimeRemaining(
            stateOfCharge: batteryPercent,
            batteryVoltage: batteryHealth.dcBusVoltage.volts,
            status: status
        )
        return ChargingDashboardViewState(
            gauge: .init(
                batteryPercent: batteryPercent,
                targetPercent: targetPercent,
                estimatedTimeRemaining: estimatedTimeRemaining,
                isBalancingAtFullCharge: isBalancingAtFullCharge,
                readout: mapReadout(
                    batteryPercent: batteryPercent,
                    targetPercent: targetPercent,
                    estimatedTimeRemaining: estimatedTimeRemaining,
                    isBalancingAtFullCharge: isBalancingAtFullCharge
                ),
                control: mapControl(chargeControl)
            ),
            maximumPower: measurementMapper.metric(
                status.map {
                    measurementMapper.power(
                        watts: chargeControl.isVisible ? chargeControl.selectedWatts : $0.maximumPowerWatts
                    )
                },
                fractionDigits: 1
            ),
            reportedCurrent: measurementMapper.metric(
                status.map { measurementMapper.current(amperes: $0.reportedCurrentAmperes) },
                fractionDigits: 1
            ),
            batteryTemperature: measurementMapper.metric(
                batteryTemperature.map { measurementMapper.temperature(celsius: $0) },
                fractionDigits: 0
            )
        )
    }

    private func mapControl(_ state: ChargeControlState) -> ChargingDashboardControlViewState {
        .init(
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
            status: mapControlStatus(state.phase)
        )
    }

    private func mapControlStatus(_ phase: ChargeControlPhase) -> ChargingDashboardStatusViewData? {
        switch phase {
        case .updating: .init(text: "UPDATING", isError: false)
        case .failed: .init(text: "UPDATE FAILED", isError: true)
        case .unavailable, .preparing, .ready: nil
        }
    }

    private func mapReadout(
        batteryPercent: Int?,
        targetPercent: Int?,
        estimatedTimeRemaining: String?,
        isBalancingAtFullCharge: Bool
    ) -> ChargingDashboardReadoutViewData {
        let title: String
        let usesEstimatedTimeStyle: Bool
        if isBalancingAtFullCharge {
            title = "BALANCING"
            usesEstimatedTimeStyle = false
        } else if let estimatedTimeRemaining {
            title = "ETA: \(estimatedTimeRemaining)"
            usesEstimatedTimeStyle = true
        } else {
            title = "CHARGING"
            usesEstimatedTimeStyle = false
        }

        let chargeState = isBalancingAtFullCharge ? "Balancing" : "Charging"
        let chargeLevel = batteryPercent.map { "\($0) percent" } ?? "unavailable"
        let target = targetPercent.map { ". Target \($0) percent" } ?? ""
        return .init(
            title: title,
            usesEstimatedTimeStyle: usesEstimatedTimeStyle,
            accessibilityLabel: "\(chargeState) \(chargeLevel)\(target)"
        )
    }

    private func averageBatteryTemperature(from temperatures: [BatteryTemperature]) -> Double? {
        guard !temperatures.isEmpty else { return nil }
        return temperatures.map(\.celsius).reduce(.zero, +) / Double(temperatures.count)
    }

    private func estimatedTimeRemaining(
        stateOfCharge: Int?,
        batteryVoltage: Double?,
        status: BikeChargingStatus?
    ) -> String? {
        guard
            let stateOfCharge,
            let batteryVoltage,
            let status,
            status.maximumStateOfChargePercent > stateOfCharge,
            batteryVoltage > .zero,
            status.reportedCurrentAmperes > .zero
        else {
            return nil
        }

        let remainingEnergyWattHours = Double(status.maximumStateOfChargePercent - stateOfCharge)
            / Constants.percentageScale
            * batteryPackCapacity.wattHours
        let chargingPowerWatts = batteryVoltage * status.reportedCurrentAmperes
        let remainingSeconds = remainingEnergyWattHours / chargingPowerWatts * Constants.secondsPerHour
        guard remainingSeconds.isFinite, remainingSeconds > .zero else { return nil }
        return Duration.seconds(remainingSeconds).formatted(timeRemainingFormatStyle)
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let fullChargePercent = 100
        static let secondsPerHour = 3_600.0
    }
}
