import BikeDomain
import ChargeControl

struct ChargingDashboardMetrics {
    let maximumPower: DashboardMetricViewData
    let chargingPower: DashboardMetricViewData
    let reportedCurrent: DashboardMetricViewData
    let batteryTemperature: DashboardMetricViewData
    let batteryTemperatureEmphasis: ChargingDashboardViewState.TemperatureEmphasis
    let activeBalancingCells: DashboardMetricViewData
}

public struct ChargingDashboardMetricsMapper: Sendable {
    private let measurementMapper: RideDashboardMeasurementMapper

    public init(measurementMapper: RideDashboardMeasurementMapper) {
        self.measurementMapper = measurementMapper
    }

    func map(
        batteryHealth: BikeBatteryHealth,
        chargeControl: ChargeControlState,
        hasReachedChargeLimit: Bool
    ) -> ChargingDashboardMetrics {
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

    private func temperatureEmphasis(
        _ celsius: Double?
    ) -> ChargingDashboardViewState.TemperatureEmphasis {
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

    private enum Constants {
        static let minimumChargingTemperatureCelsius = 4.0
        static let lowTemperatureWarningCelsius = 10.0
        static let warningTemperatureCelsius = 50.0
        static let criticalTemperatureCelsius = 60.0
    }
}
