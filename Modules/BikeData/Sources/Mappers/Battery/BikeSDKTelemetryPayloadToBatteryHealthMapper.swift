import BikeDomain
import BikeSDK
import Foundation

public struct BikeSDKTelemetryPayloadToBatteryHealthMapper: Sendable {
    public init() {}

    public func apply(
        _ payload: BikeSDKTelemetryPayload,
        to health: inout BikeBatteryHealth,
        date: Date
    ) {
        switch payload {
        case .battery(let battery):
            health.stateOfCharge = .known(percent: battery.stateOfChargePercent)
            health.stateOfHealth = healthLevel(percent: battery.stateOfHealthPercent)
            health.dcBusVoltage = dcBusVoltage(rawValue: battery.dcBusRaw)
            health.lastUpdated = date
        case .status(let status):
            health.chargeState = chargeState(
                isCharging: status.isCharging,
                isChargerConnected: status.isChargerConnected
            )
            health.isFaultActive = status.isFaultActive
            health.lastUpdated = date
        case .cellVoltages(let payload):
            health.cellVoltages = payload.volts.enumerated().map {
                BatteryCellVoltage(
                    position: $0.offset + BatteryHealthConstants.firstCellPosition,
                    volts: $0.element
                )
            }
            health.lastUpdated = date
        case .batteryTemperatures(let payload):
            health.temperatures = payload.celsius.enumerated().map {
                BatteryTemperature(
                    position: $0.offset + BatteryHealthConstants.firstTemperaturePosition,
                    celsius: $0.element
                )
            }
            health.lastUpdated = date
        case .batteryBalancing(let payload):
            health.balancingCellIndexes = payload.activeCellIndexes
            health.lastUpdated = date
        case .charger(let payload):
            health.chargingStatus = BikeChargingStatus(
                requestedCurrentAmperes: payload.requestedCurrentAmperes,
                reportedCurrentAmperes: payload.reportedCurrentAmperes,
                maximumCurrentAmperes: payload.maximumCurrentAmperes,
                maximumPowerWatts: payload.maximumPowerWatts,
                targetCellVoltageVolts: payload.targetCellVoltageVolts,
                maximumStateOfChargePercent: payload.maximumStateOfChargePercent,
                chargerType: BikeChargerType(rawValue: payload.typeRaw)
            )
            health.lastUpdated = date
        case .vcuBrake, .map, .speed, .throttle, .imu, .liveTotals, .inverterTemperatures, .vin:
            break
        }
    }

    private func healthLevel(percent: Int?) -> HealthLevel {
        guard let percent else { return .unknown }
        return .known(percent: percent)
    }

    private func dcBusVoltage(rawValue: Int?) -> BatteryVoltage {
        guard let rawValue else { return .unknown }
        return .known(volts: Double(rawValue) / BatteryHealthConstants.dcBusScale)
    }

    private func chargeState(isCharging: Bool, isChargerConnected: Bool) -> BatteryChargeState {
        if isCharging { return .charging }
        return isChargerConnected ? .connected : .disconnected
    }
}

private enum BatteryHealthConstants {
    static let dcBusScale = 10.0
    static let firstCellPosition = 1
    static let firstTemperaturePosition = 1
}
