import BikeDomain
import ChargeControl

public struct ChargingDashboardMapper: Sendable {
    private let controlStatusMapper: ChargingDashboardControlStatusMapper
    private let readoutMapper: ChargingDashboardReadoutMapper
    private let metricsMapper: ChargingDashboardMetricsMapper
    private let timeRemainingEstimator: ChargingTimeRemainingEstimator

    public init(
        controlStatusMapper: ChargingDashboardControlStatusMapper,
        readoutMapper: ChargingDashboardReadoutMapper,
        metricsMapper: ChargingDashboardMetricsMapper,
        timeRemainingEstimator: ChargingTimeRemainingEstimator
    ) {
        self.controlStatusMapper = controlStatusMapper
        self.readoutMapper = readoutMapper
        self.metricsMapper = metricsMapper
        self.timeRemainingEstimator = timeRemainingEstimator
    }

    public func map(
        telemetry: BikeTelemetry,
        batteryHealth: BikeBatteryHealth,
        chargeControl: ChargeControlState = .init()
    ) -> ChargingDashboardViewState {
        let status = batteryHealth.chargingStatus
        let targetPercent = status.map {
            chargeControl.isVisible
                ? Int(chargeControl.selectedTargetPercent.rounded())
                : $0.maximumStateOfChargePercent
        }
        let batteryPercent = telemetry.batteryLevel.percent
        let isBalancing = batteryPercent == Constants.fullChargePercent
            && !batteryHealth.balancingCellIndexes.isEmpty
        let hasReachedLimit = !isBalancing
            && batteryPercent.map { level in targetPercent.map { level >= $0 } ?? false } == true
        let estimatedTimeRemaining = timeRemainingEstimator.estimate(
            stateOfCharge: batteryPercent,
            targetPercent: targetPercent,
            batteryVoltage: batteryHealth.dcBusVoltage.volts,
            status: status
        )
        let metrics = metricsMapper.map(
            batteryHealth: batteryHealth,
            chargeControl: chargeControl,
            hasReachedChargeLimit: hasReachedLimit
        )
        return ChargingDashboardViewState(
            batteryPercent: batteryPercent,
            targetPercent: targetPercent,
            estimatedTimeRemaining: estimatedTimeRemaining,
            isBalancingAtFullCharge: isBalancing,
            readout: readoutMapper.map(.init(
                batteryPercent: batteryPercent,
                targetPercent: targetPercent,
                estimatedTimeRemaining: estimatedTimeRemaining,
                isBalancingAtFullCharge: isBalancing,
                hasReachedChargeLimit: hasReachedLimit,
                isChargerConnected: telemetry.statusFlags.isChargerConnected,
                batteryHealth: batteryHealth
            )),
            control: mapControl(chargeControl, hasReachedChargeLimit: hasReachedLimit),
            maximumPower: metrics.maximumPower,
            chargingPower: metrics.chargingPower,
            reportedCurrent: metrics.reportedCurrent,
            batteryTemperature: metrics.batteryTemperature,
            batteryTemperatureEmphasis: metrics.batteryTemperatureEmphasis,
            activeBalancingCells: metrics.activeBalancingCells
        )
    }

    private func mapControl(
        _ state: ChargeControlState,
        hasReachedChargeLimit: Bool
    ) -> ChargingDashboardControlViewState {
        let canAcceptInput = state.canAcceptInput
        return .init(
            isEnabled: canAcceptInput,
            power: .init(
                isEnabled: canAcceptInput && !hasReachedChargeLimit,
                selected: state.selectedWatts,
                minimum: state.minimumWatts,
                maximum: state.maximumWatts,
                step: state.stepWatts
            ),
            target: .init(
                isEnabled: canAcceptInput,
                selected: state.selectedTargetPercent,
                minimum: state.minimumTargetPercent,
                maximum: state.maximumTargetPercent,
                step: state.targetStepPercent
            ),
            status: controlStatusMapper.map(state)
        )
    }

    private enum Constants {
        static let fullChargePercent = 100
    }
}
