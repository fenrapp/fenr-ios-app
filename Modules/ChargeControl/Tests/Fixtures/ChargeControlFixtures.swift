import BikeDomain

enum ChargeControlFixtures {
    static func chargingHealth(
        powerWatts: Double = 1_000,
        targetPercent: Int = 100,
        chargerType: BikeChargerType = .backpack
    ) -> BikeBatteryHealth {
        .init(
            chargeState: .charging,
            chargingStatus: .init(
                requestedCurrentAmperes: 2.5,
                reportedCurrentAmperes: 2.5,
                maximumCurrentAmperes: 20,
                maximumPowerWatts: powerWatts,
                targetCellVoltageVolts: 4.275,
                maximumStateOfChargePercent: targetPercent,
                chargerType: chargerType
            )
        )
    }
}
