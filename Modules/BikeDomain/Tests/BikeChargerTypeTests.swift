import BikeDomain
import Testing

@Suite("Bike charger type")
struct BikeChargerTypeTests {
    @Test("Maps persisted charger identifiers", arguments: [
        (0, BikeChargerType.standard),
        (2, BikeChargerType.fast),
        (3, BikeChargerType.backpack),
        (91, BikeChargerType.unknown(91))
    ])
    func mapsRawIdentifiers(rawValue: Int, expected: BikeChargerType) {
        let charger = BikeChargerType(rawValue: rawValue)

        #expect(charger == expected)
        #expect(charger.rawValue == rawValue)
    }

    @Test("Uses the validated charger power ceilings", arguments: [
        (BikeChargerType.standard, 3_300),
        (BikeChargerType.fast, 7_000),
        (BikeChargerType.backpack, 3_300),
        (BikeChargerType.unknown(91), 3_300)
    ])
    func maximumChargePower(charger: BikeChargerType, expectedWatts: Int) {
        #expect(charger.maximumChargePowerWatts == expectedWatts)
    }
}
