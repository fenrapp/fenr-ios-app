@testable import BikeData
import BikeDomain
import Foundation
import Testing

@Suite("Bike Alpha evidence persistence")
struct BikeAlphaEvidencePersistenceTests {
    @Test("Restores evidence only for the exact profile VIN")
    func restoresOnlyMatchingEvidence() async {
        let repository = ControllableBikeProfileRepository(profile: .init(
            vin: BikeProfilePersistenceFixtures.vin,
            alphaEvidence: [.powerAboveStandard]
        ))
        let persistence = BikeAlphaEvidencePersistence(profileRepository: repository)

        let matching = await persistence.persistedEvidence(
            matching: BikeProfilePersistenceFixtures.vin
        )
        let mismatching = await persistence.persistedEvidence(
            matching: "FENRTEST000000002"
        )

        #expect(matching == [.powerAboveStandard])
        #expect(mismatching.isEmpty)
    }

    @Test("Unions new evidence once with the supplied timestamp and preserves the profile")
    func persistsNewEvidence() async {
        let previousDate = Date(timeIntervalSince1970: 1_600_000_000)
        let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let original = BikeProfile(
            vin: BikeProfilePersistenceFixtures.vin,
            declaredPowerTier: .alpha,
            alphaEvidence: [.powerAboveStandard],
            alphaDetectedAt: previousDate
        )
        let repository = ControllableBikeProfileRepository(profile: original)
        let persistence = BikeAlphaEvidencePersistence(profileRepository: repository)
        let telemetry = BikeTelemetry(
            detectedPowerTier: .alpha(evidence: [.tractionControlConfigured])
        )

        await persistence.persistNewEvidence(from: telemetry, observedAt: observedAt)
        await persistence.persistNewEvidence(from: telemetry, observedAt: observedAt)

        let expected = BikeProfile(
            vin: original.vin,
            declaredPowerTier: original.declaredPowerTier,
            alphaEvidence: [.powerAboveStandard, .tractionControlConfigured],
            alphaDetectedAt: observedAt
        )
        #expect(await repository.savedProfiles == [expected])
        #expect(await repository.loadProfile() == expected)
    }

    @Test("Skips empty, Standard, existing, and mismatched evidence")
    func skipsEvidenceThatMustNotBeSaved() async {
        let profile = BikeProfile(
            vin: BikeProfilePersistenceFixtures.vin,
            alphaEvidence: [.powerAboveStandard],
            alphaDetectedAt: BikeProfilePersistenceFixtures.detectedAt
        )
        let repository = ControllableBikeProfileRepository(profile: profile)
        let persistence = BikeAlphaEvidencePersistence(profileRepository: repository)
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)

        await persistence.persistNewEvidence(
            from: BikeTelemetry(detectedPowerTier: .alpha(evidence: [])),
            observedAt: observedAt
        )
        await persistence.persistNewEvidence(
            from: BikeTelemetry(detectedPowerTier: .standardBaseline),
            observedAt: observedAt
        )
        await persistence.persistNewEvidence(
            from: BikeTelemetry(
                vin: BikeProfilePersistenceFixtures.vin,
                detectedPowerTier: .alpha(evidence: [.powerAboveStandard])
            ),
            observedAt: observedAt
        )
        await persistence.persistNewEvidence(
            from: BikeTelemetry(
                vin: "FENRTEST000000002",
                detectedPowerTier: .alpha(evidence: [.tractionControlConfigured])
            ),
            observedAt: observedAt
        )

        #expect(await repository.savedProfiles.isEmpty)
        #expect(await repository.loadProfile() == profile)
    }
}
