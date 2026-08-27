import BikeDomain
import ChargeControl
import Foundation
import SettingsDomain

public struct ChargingDashboardMapper: Sendable {
    private let measurementMapper: RideDashboardMeasurementMapper
    private let timeRemainingFormatStyle: Duration.UnitsFormatStyle
    private let batteryPackCapacity: BatteryPackCapacity
    private let controlStatusMapper: ChargingDashboardControlStatusMapper

    public init(
        measurementMapper: RideDashboardMeasurementMapper,
        timeRemainingFormatStyle: Duration.UnitsFormatStyle,
        batteryPackCapacity: BatteryPackCapacity,
        controlStatusMapper: ChargingDashboardControlStatusMapper
    ) {
        self.measurementMapper = measurementMapper
        self.timeRemainingFormatStyle = timeRemainingFormatStyle
        self.batteryPackCapacity = batteryPackCapacity
        self.controlStatusMapper = controlStatusMapper
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
        let isBalancingAtFullCharge = batteryPercent == Constants.fullChargePercent
            && !batteryHealth.balancingCellIndexes.isEmpty
        let hasReachedChargeLimit = !isBalancingAtFullCharge && hasReachedChargeLimit(
            batteryPercent: batteryPercent,
            targetPercent: targetPercent
        )
        let estimatedTimeRemaining = estimatedTimeRemaining(
            stateOfCharge: batteryPercent,
            targetPercent: targetPercent,
            batteryVoltage: batteryHealth.dcBusVoltage.volts,
            status: status
        )
        let metrics = mapMetrics(
            batteryHealth: batteryHealth,
            chargeControl: chargeControl,
            hasReachedChargeLimit: hasReachedChargeLimit
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
                hasReachedChargeLimit: hasReachedChargeLimit,
                isChargerConnected: telemetry.statusFlags.isChargerConnected,
                batteryHealth: batteryHealth
            )),
            control: mapControl(
                chargeControl,
                hasReachedChargeLimit: hasReachedChargeLimit
            ),
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
        .init(
            isEnabled: state.isEnabled,
            power: .init(
                isEnabled: state.isEnabled && !hasReachedChargeLimit,
                selected: state.selectedWatts,
                minimum: state.minimumWatts,
                maximum: state.maximumWatts,
                step: state.stepWatts
            ),
            target: .init(
                isEnabled: state.isEnabled,
                selected: state.selectedTargetPercent,
                minimum: state.minimumTargetPercent,
                maximum: state.maximumTargetPercent,
                step: state.targetStepPercent
            ),
            status: controlStatusMapper.map(state)
        )
    }

    private func mapReadout(_ context: ReadoutContext) -> ChargingDashboardReadoutViewData {
        if let exceptionalState = exceptionalReadout(context) {
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
}

private extension ChargingDashboardMapper {
    private func exceptionalReadout(
        _ context: ReadoutContext
    ) -> ChargingDashboardReadoutViewData? {
        guard !context.isBalancingAtFullCharge else { return nil }
        guard context.isChargerConnected else {
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
        guard context.batteryHealth.lastUpdated != nil,
              context.batteryHealth.chargeState != .unknown,
              context.batteryHealth.chargingStatus != nil else {
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
        if context.hasReachedChargeLimit { return reachedLimitReadout(context) }
        guard context.batteryHealth.chargeState != .connected else {
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
        guard context.batteryHealth.chargeState != .disconnected else {
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

    private func reachedLimitReadout(_ context: ReadoutContext) -> ChargingDashboardReadoutViewData {
        let batteryLevel = context.batteryPercent.map { "BATTERY \($0)%" }
        let target = context.targetPercent.map { "TARGET \($0)%" }
        let subtitle = [target, batteryLevel].compactMap { $0 }.joined(separator: " · ")
        return .init(
            title: "LIMIT REACHED",
            subtitle: subtitle.isEmpty ? nil : subtitle,
            accessibilityLabel: ["Charge limit reached", target, batteryLevel]
                .compactMap { $0 }
                .joined(separator: ". "),
            systemImage: "checkmark.circle.fill",
            emphasis: .charging,
            allowsControl: true
        )
    }

    private func mapMetrics(
        batteryHealth: BikeBatteryHealth,
        chargeControl: ChargeControlState,
        hasReachedChargeLimit: Bool
    ) -> MappedMetrics {
        let status = batteryHealth.chargingStatus
        let reportedCurrent = status.map {
            hasReachedChargeLimit ? .zero : $0.reportedCurrentAmperes
        }
        let chargingPower = reportedCurrent.flatMap { current in
            batteryHealth.dcBusVoltage.volts.map { $0 * current }
        }
        let batteryTemperature = averageBatteryTemperature(from: batteryHealth.temperatures)
        return .init(
            maximumPower: measurementMapper.metric(
                status.map {
                    measurementMapper.power(
                        watts: chargeControl.isVisible ? chargeControl.selectedWatts : $0.maximumPowerWatts
                    )
                },
                fractionDigits: 1
            ),
            chargingPower: measurementMapper.metric(
                chargingPower.map { measurementMapper.power(watts: $0) },
                fractionDigits: 1
            ),
            reportedCurrent: measurementMapper.metric(
                reportedCurrent.map { measurementMapper.current(amperes: $0) },
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

    private func hasReachedChargeLimit(batteryPercent: Int?, targetPercent: Int?) -> Bool {
        guard let batteryPercent, let targetPercent else { return false }
        return batteryPercent >= targetPercent
    }

    private func estimatedTimeRemaining(
        stateOfCharge: Int?,
        targetPercent: Int?,
        batteryVoltage: Double?,
        status: BikeChargingStatus?
    ) -> String? {
        guard
            let stateOfCharge,
            let targetPercent,
            let batteryVoltage,
            let status,
            targetPercent > stateOfCharge,
            batteryVoltage > .zero,
            status.reportedCurrentAmperes > .zero
        else {
            return nil
        }

        let remainingEnergyWattHours = Double(targetPercent - stateOfCharge)
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
        let hasReachedChargeLimit: Bool
        let isChargerConnected: Bool
        let batteryHealth: BikeBatteryHealth
    }

    private struct MappedMetrics {
        let maximumPower: DashboardMetricViewData
        let chargingPower: DashboardMetricViewData
        let reportedCurrent: DashboardMetricViewData
        let batteryTemperature: DashboardMetricViewData
        let batteryTemperatureEmphasis: ChargingDashboardViewState.TemperatureEmphasis
        let activeBalancingCells: DashboardMetricViewData
    }
}
