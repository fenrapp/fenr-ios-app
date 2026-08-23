import StarkProtocol
import Testing

@Suite("Stark UUID catalog")
struct StarkUUIDCatalogTests {
    @Test("Catalog matches the proprietary UUIDs in VARG 3.2.3")
    func officialCatalog() {
        let catalog = StarkUUIDCatalog.services + StarkUUIDCatalog.proprietaryCharacteristics
        let actualUUIDs = Set(catalog.map { $0.uuidString.lowercased() })

        #expect(actualUUIDs == StarkUUIDFixtures.officialProprietaryUUIDs)
    }

    @Test("Catalog separates services and characteristics without duplicates")
    func catalogGroups() {
        let services = StarkUUIDCatalog.services
        let characteristics = StarkUUIDCatalog.proprietaryCharacteristics

        #expect(services.count == StarkUUIDFixtures.serviceCount)
        #expect(characteristics.count == StarkUUIDFixtures.proprietaryCharacteristicCount)
        #expect(Set(services).count == services.count)
        #expect(Set(characteristics).count == characteristics.count)
        #expect(Set(services).isDisjoint(with: Set(characteristics)))
    }

    @Test("Standard battery level stays outside the Stark namespace")
    func standardBatteryLevel() throws {
        let characteristic = try #require(StarkUUIDCatalog.standardCharacteristics.first)

        #expect(StarkUUIDCatalog.standardCharacteristics.count == StarkUUIDFixtures.standardCharacteristicCount)
        #expect(characteristic == StarkUUIDs.bikeBatteryLevel)
        #expect(characteristic.uuidString.lowercased() == StarkUUIDFixtures.standardBatteryLevel)
        #expect(!StarkUUIDFixtures.officialProprietaryUUIDs.contains(characteristic.uuidString.lowercased()))
    }

    @Test("Official VARG 3.2.3 semantic assignments remain explicit")
    func officialSemanticAssignments() {
        #expect(StarkUUIDs.batteryCellVoltages.uuidString.hasPrefix("00006007"))
        #expect(StarkUUIDs.batteryBalancing.uuidString.hasPrefix("00006008"))
        #expect(StarkUUIDs.inverterInfo.uuidString.hasPrefix("00007001"))
        #expect(StarkUUIDs.inverterSignals.uuidString.hasPrefix("00007002"))
        #expect(StarkUUIDs.inverterTemperatures.uuidString.hasPrefix("00007003"))
    }
}
