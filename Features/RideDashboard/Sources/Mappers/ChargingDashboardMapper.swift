import BikeDomain
import Foundation
import SettingsDomain

public struct ChargingDashboardMapper: Sendable {
    private let measurementMapper: RideDashboardMeasurementMapper

    public init(
        measurementSystem: MeasurementSystem = .system,
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours,
        locale: Locale = .autoupdatingCurrent
    ) {
        measurementMapper = RideDashboardMeasurementMapper(
            measurementSystem: measurementSystem,
            locale: locale
        )
        self.batteryPackCapacity = batteryPackCapacity
    }

    private let batteryPackCapacity: BatteryPackCapacity

    public func map(
        telemetry: BikeTelemetry,
        batteryHealth: BikeBatteryHealth
    ) -> ChargingDashboardViewState {
        let status = batteryHealth.chargingStatus
        let batteryTemperature = averageBatteryTemperature(from: batteryHealth.temperatures)
        return ChargingDashboardViewState(
            batteryPercent: telemetry.batteryLevel.percent,
            maximumPower: status.map { measurementMapper.power(watts: $0.maximumPowerWatts) },
            reportedCurrent: status.map { measurementMapper.current(amperes: $0.reportedCurrentAmperes) },
            batteryTemperature: batteryTemperature.map { measurementMapper.temperature(celsius: $0) },
            targetStateOfChargePercent: status?.maximumStateOfChargePercent,
            estimatedTimeRemaining: estimatedTimeRemaining(
                stateOfCharge: telemetry.batteryLevel.percent,
                batteryVoltage: batteryHealth.dcBusVoltage.volts,
                status: status
            ),
            isBalancingAtFullCharge: telemetry.batteryLevel.percent == Constants.fullChargePercent
                && !batteryHealth.balancingCellIndexes.isEmpty,
            isHighBeamOn: telemetry.statusFlags.indicatorState.isHighBeamOn,
            isLeftBlinkerOn: telemetry.statusFlags.indicatorState.isLeftBlinkerOn,
            isBrakeActive: telemetry.statusFlags.isBrakeActive,
            isRightBlinkerOn: telemetry.statusFlags.indicatorState.isRightBlinkerOn,
            isFaultActive: telemetry.statusFlags.isFaultActive
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
        return ChargingTimeRemainingFormatter().string(from: remainingSeconds)
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let fullChargePercent = 100
        static let secondsPerHour = 3_600.0
    }
}
