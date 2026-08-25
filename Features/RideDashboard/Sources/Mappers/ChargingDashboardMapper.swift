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
        let chargingPowerWatts = status.flatMap { status in
            batteryHealth.dcBusVoltage.volts.map { $0 * status.reportedCurrentAmperes }
        }
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
            batteryPercent: batteryPercent,
            targetPercent: targetPercent,
            estimatedTimeRemaining: estimatedTimeRemaining,
            isBalancingAtFullCharge: isBalancingAtFullCharge,
            readout: mapReadout(.init(
                batteryPercent: batteryPercent,
                targetPercent: targetPercent,
                estimatedTimeRemaining: estimatedTimeRemaining,
                isBalancingAtFullCharge: isBalancingAtFullCharge,
                isChargerConnected: telemetry.statusFlags.isChargerConnected,
                batteryHealth: batteryHealth
            )),
            control: mapControl(chargeControl),
            maximumPower: measurementMapper.metric(
                status.map {
                    measurementMapper.power(
                        watts: chargeControl.isVisible ? chargeControl.selectedWatts : $0.maximumPowerWatts
                    )
                },
                fractionDigits: 1
            ),
            chargingPower: measurementMapper.metric(
                chargingPowerWatts.map { measurementMapper.power(watts: $0) },
                fractionDigits: 1
            ),
            reportedCurrent: measurementMapper.metric(
                status.map { measurementMapper.current(amperes: $0.reportedCurrentAmperes) },
                fractionDigits: 1
            ),
            batteryTemperature: measurementMapper.metric(
                batteryTemperature.map { measurementMapper.temperature(celsius: $0) },
                fractionDigits: 0
            ),
            batteryTemperatureEmphasis: temperatureEmphasis(batteryTemperature),
            activeBalancingCells: .init(
                valueText: batteryHealth.balancingCellIndexes.count.formatted(),
                animationValue: Double(batteryHealth.balancingCellIndexes.count)
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

    private func mapReadout(_ context: ReadoutContext) -> ChargingDashboardReadoutViewData {
        if let exceptionalState = exceptionalReadout(
            isBalancingAtFullCharge: context.isBalancingAtFullCharge,
            isChargerConnected: context.isChargerConnected,
            batteryHealth: context.batteryHealth
        ) {
            return exceptionalState
        }

        let title: String
        let subtitle: String?
        if context.isBalancingAtFullCharge {
            title = "BALANCING"
            let activeCellCount = context.batteryHealth.balancingCellIndexes.count
            subtitle = "\(activeCellCount) \(activeCellCount == 1 ? "CELL" : "CELLS") ACTIVE"
        } else if let estimatedTimeRemaining = context.estimatedTimeRemaining {
            title = "ETA: \(estimatedTimeRemaining)"
            subtitle = context.targetPercent.map { "TARGET \($0)%" }
        } else {
            title = "CHARGING"
            subtitle = context.targetPercent.map { "TARGET \($0)%" }
        }

        let chargeState = context.isBalancingAtFullCharge ? "Balancing" : "Charging"
        let chargeLevel = context.batteryPercent.map { "\($0) percent" } ?? "unavailable"
        let target = context.targetPercent.map { ". Target \($0) percent" } ?? ""
        return .init(
            title: title,
            subtitle: subtitle,
            accessibilityLabel: "\(chargeState) \(chargeLevel)\(target)",
            emphasis: context.isBalancingAtFullCharge ? .balancing : .charging,
            allowsControl: !context.isBalancingAtFullCharge
        )
    }

    private func exceptionalReadout(
        isBalancingAtFullCharge: Bool,
        isChargerConnected: Bool,
        batteryHealth: BikeBatteryHealth
    ) -> ChargingDashboardReadoutViewData? {
        guard !isBalancingAtFullCharge else { return nil }
        guard isChargerConnected else {
            return .init(
                title: "CHARGER",
                subtitle: "DISCONNECTED",
                accessibilityLabel: "Charger disconnected",
                systemImage: "bolt.slash.fill",
                emphasis: .critical,
                allowsControl: false,
                showsProgress: false
            )
        }
        guard batteryHealth.lastUpdated != nil,
              batteryHealth.chargeState != .unknown,
              batteryHealth.chargingStatus != nil else {
            return .init(
                title: "CHARGING",
                subtitle: "DATA UNAVAILABLE",
                accessibilityLabel: "Charging data unavailable",
                systemImage: "exclamationmark.triangle.fill",
                emphasis: .warning,
                allowsControl: false,
                showsProgress: false
            )
        }
        guard batteryHealth.chargeState != .connected else {
            return .init(
                title: "CHARGER",
                subtitle: "CONNECTED · IDLE",
                accessibilityLabel: "Charger connected but not charging",
                systemImage: "powerplug.fill",
                emphasis: .warning,
                allowsControl: false,
                showsProgress: false
            )
        }
        guard batteryHealth.chargeState != .disconnected else {
            return .init(
                title: "CHARGER",
                subtitle: "DISCONNECTED",
                accessibilityLabel: "Charger disconnected",
                systemImage: "bolt.slash.fill",
                emphasis: .critical,
                allowsControl: false,
                showsProgress: false
            )
        }
        return nil
    }

    private func temperatureEmphasis(_ celsius: Double?) -> ChargingDashboardViewState.TemperatureEmphasis {
        guard let celsius else { return .unavailable }
        return switch celsius {
        case ..<Constants.minimumChargingTemperatureCelsius: .critical
        case Constants.criticalTemperatureCelsius...: .critical
        case Constants.minimumChargingTemperatureCelsius ..< Constants.lowTemperatureWarningCelsius: .warning
        case Constants.warningTemperatureCelsius...: .warning
        default: .normal
        }
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
        static let minimumChargingTemperatureCelsius = 4.0
        static let lowTemperatureWarningCelsius = 10.0
        static let warningTemperatureCelsius = 50.0
        static let criticalTemperatureCelsius = 60.0
    }

    private struct ReadoutContext {
        let batteryPercent: Int?
        let targetPercent: Int?
        let estimatedTimeRemaining: String?
        let isBalancingAtFullCharge: Bool
        let isChargerConnected: Bool
        let batteryHealth: BikeBatteryHealth
    }
}
