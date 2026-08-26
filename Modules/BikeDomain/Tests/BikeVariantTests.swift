@testable import BikeDomain
import Testing

@Suite("Bike variant")
struct BikeVariantTests {
    @Test("Derives supported variants from the VIN product prefix")
    func derivesSupportedVariants() {
        #expect(BikeVariant(vin: "UDUMXTEST00000001") == .mx)
        #expect(BikeVariant(vin: "UDUEXTEST00000001") == .ex)
        #expect(BikeVariant(vin: "UDUSMTEST00000001") == .sm)
    }

    @Test("Matches normalized VIN prefixes case-insensitively")
    func matchesCaseInsensitively() {
        #expect(BikeVariant(vin: "udusmtest00000001") == .sm)
    }

    @Test("Keeps unrecognized product prefixes forward compatible")
    func preservesUnknownVariants() {
        #expect(BikeVariant(vin: "FENRTEST000000001") == .unknown)
    }

    @Test("Bike profiles expose the variant derived from their VIN")
    func profileExposesDerivedVariant() {
        let profile = BikeProfile(vin: "UDUSMTEST00000001")

        #expect(profile.variant == .sm)
    }
}
