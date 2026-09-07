import BikeDomain
import Foundation

enum BatteryObservationData {
    static var chargingHealth: BikeBatteryHealth {
        .init(
            chargeState: .charging,
            chargingStatus: .init(
                requestedCurrentAmperes: 2.5, reportedCurrentAmperes: 2.5,
                maximumCurrentAmperes: 20, maximumPowerWatts: 1_000,
                targetCellVoltageVolts: 4.275, maximumStateOfChargePercent: 100, chargerType: .backpack
            ),
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
