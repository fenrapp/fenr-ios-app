import BikeDomain
import Testing

@Suite("Bike profile compatibility")
struct BikeProfileCompatibilityTests {
    @Test("Keeps persisted declared power tier identifiers stable", arguments: [
        (BikeDeclaredPowerTier.standard, "standard"),
        (BikeDeclaredPowerTier.alpha, "alpha")
    ])
    func declaredPowerTierRawValue(tier: BikeDeclaredPowerTier, expected: String) {
        #expect(tier.rawValue == expected)
        #expect(BikeDeclaredPowerTier(rawValue: expected) == tier)
    }

    @Test("Keeps persisted alpha evidence identifiers stable", arguments: [
        (BikeAlphaEvidence.powerAboveStandard, "powerAboveStandard"),
        (BikeAlphaEvidence.tractionControlConfigured, "tractionControlConfigured")
    ])
    func alphaEvidenceRawValue(evidence: BikeAlphaEvidence, expected: String) {
        #expect(evidence.rawValue == expected)
        #expect(BikeAlphaEvidence(rawValue: expected) == evidence)
    }
}
