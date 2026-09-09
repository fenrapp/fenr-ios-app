import BikeDomain

enum PowerModeCurveConfirmationFixtures {
    static func configuration(
        map: Int = 0, power: Int = 500, regeneration: Int = 200
    ) -> BikeAdvancedPowerModeConfiguration {
        .init(
            mapIndex: map, firmware: "1.10.1", torqueRaw: 50, regenerationRaw: 20, curve: map + 1,
            power: Array(repeating: power, count: 15), regeneration: Array(repeating: regeneration, count: 15),
            powerTractionRaw: 0, brakingTractionRaw: 0
        )
    }
}
