import BikeDomain
import Foundation

enum BikeEmulatorChargingStatusFactory {
    static func make(
        tick: Int,
        chargePowerLimitWatts: Int,
        chargeTargetPercent: Int,
        isCharging: Bool,
        chargingBusVoltage: Double
    ) -> BikeChargingStatus {
        let chargeLoad = isCharging ? abs(sin(Double(tick) * Constants.loadWaveRadians)) : .zero
        let requestedCurrent = isCharging
            ? Constants.baseCurrent + chargeLoad * Constants.currentAmplitude
            : .zero
        return BikeChargingStatus(
            requestedCurrentAmperes: requestedCurrent,
            reportedCurrentAmperes: min(
                requestedCurrent,
                Double(chargePowerLimitWatts) / chargingBusVoltage
            ),
            maximumCurrentAmperes: Constants.maximumCurrent,
            maximumPowerWatts: Double(chargePowerLimitWatts),
            targetCellVoltageVolts: Constants.targetCellVoltage,
            maximumStateOfChargePercent: chargeTargetPercent,
            chargerType: .backpack
        )
    }

    private enum Constants {
        static let baseCurrent = 2.5
        static let currentAmplitude = 12.0
        static let loadWaveRadians = 0.14
        static let maximumCurrent = 20.0
        static let targetCellVoltage = 4.275
    }
}
