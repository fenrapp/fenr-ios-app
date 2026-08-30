import BikeDomain
import BikeSDK
import Foundation

public struct BikeSDKTelemetryPayloadToBatteryHealthMapper: Sendable {
    public init() {}

    @discardableResult
    public func apply(
        _ payload: BikeSDKTelemetryPayload,
        to health: inout BikeBatteryHealth,
        date: Date
    ) -> Bool {
        switch payload {
        case .batteryStatus(let status):
            health.positiveBMSFaultBits = status.positiveFaultBits
            health.negativeBMSFaultBits = status.negativeFaultBits
            health.lastUpdated = date
        case .battery(let battery):
            health.stateOfCharge = .known(percent: battery.stateOfChargePercent)
            health.stateOfHealth = healthLevel(percent: battery.stateOfHealthPercent)
            health.dcBusVoltage = dcBusVoltage(volts: battery.dcBusVolts)
            health.lastUpdated = date
        case .status(let status):
            health.chargeState = chargeState(
                isCharging: status.isCharging,
                isChargerConnected: status.isChargerConnected
            )
            health.isVehicleFaultActive = status.isFaultActive
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
        case .batteryParameters, .batterySignals, .vcuBrake, .map,
             .powerModeConfiguration, .tractionControlConfiguration, .speed,
             .throttle, .imu, .liveTotals, .liveEstimations, .inverterTemperatures, .vin:
            return false
        }
        return true
    }

    private func healthLevel(percent: Int?) -> HealthLevel {
        guard let percent else { return .unknown }
        return .known(percent: percent)
    }

    private func dcBusVoltage(volts: Double?) -> BatteryVoltage {
        guard let volts else { return .unknown }
        return .known(volts: volts)
    }

    private func chargeState(isCharging: Bool, isChargerConnected: Bool) -> BatteryChargeState {
        if isCharging { return .charging }
        return isChargerConnected ? .connected : .disconnected
    }
}

private enum BatteryHealthConstants {
    static let firstCellPosition = 1
    static let firstTemperaturePosition = 1
}
