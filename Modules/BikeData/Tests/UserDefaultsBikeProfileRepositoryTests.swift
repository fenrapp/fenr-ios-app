@testable import BikeData
import BikeDomain
import Foundation
import Testing

@MainActor
@Suite("UserDefaults bike profile repository")
struct UserDefaultsBikeProfileRepositoryTests {
    @Test("Loads an empty profile when no bike has completed onboarding")
    func loadsEmptyProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )

        #expect(await repository.loadProfile() == nil)

        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Persists a configured bike profile")
    func savesAndReloadsProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        let profile = BikeProfile(vin: "UDUSMTEST00000001")

        await repository.saveProfile(profile)

        let reloadedRepository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )
        #expect(await reloadedRepository.loadProfile() == profile)
        #expect(await reloadedRepository.loadProfile()?.variant == .sm)

        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Clears the configured bike profile")
    func clearsProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        await repository.saveProfile(.init(vin: "FENRTEST000000001"))

        await repository.clearProfile()

        #expect(await repository.loadProfile() == nil)

        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Persists declared tier and positive Alpha evidence by VIN")
    func persistsPowerTierEvidence() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        let detectedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = BikeProfile(
            vin: "FENRTEST000000001",
            declaredPowerTier: .alpha,
            alphaEvidence: [.powerAboveStandard, .tractionControlConfigured],
            alphaDetectedAt: detectedAt
        )

        await repository.saveProfile(profile)

        #expect(await repository.loadProfile() == profile)
        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Does not notify observers when the saved profile is unchanged")
    func skipsDuplicateProfileNotifications() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        let stream = await repository.observeProfile()
        var iterator = stream.makeAsyncIterator()
        let standard = BikeProfile(vin: "FENRTEST000000001")
        let alpha = BikeProfile(vin: "FENRTEST000000001", declaredPowerTier: .alpha)

        let initialState = await iterator.next()
        #expect(initialState == BikeProfileState(profile: nil))
        await repository.saveProfile(standard)
        let savedState = await iterator.next()
        #expect(savedState == BikeProfileState(profile: standard))
        await repository.saveProfile(standard)
        await repository.saveProfile(alpha)

        let updatedState = await iterator.next()
        #expect(updatedState == BikeProfileState(profile: alpha))
        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Loads stable legacy keys with fallback without rewriting raw values")
    func loadsLegacyKeysWithoutRewriting() async throws {
        let suiteName = makeSuiteName()
        let setupDefaults = makeDefaults(suiteName: suiteName)
        setupDefaults.set(
            BikeProfilePersistenceFixtures.vin,
            forKey: BikeProfilePersistenceFixtures.profileVINKey
        )
        setupDefaults.set(
            "future-tier",
            forKey: BikeProfilePersistenceFixtures.declaredPowerTierKey
        )
        setupDefaults.set(
            [BikeAlphaEvidence.powerAboveStandard.rawValue, "future-evidence"],
            forKey: BikeProfilePersistenceFixtures.alphaEvidenceKey
        )
        setupDefaults.set(
            BikeProfilePersistenceFixtures.detectedAt,
            forKey: BikeProfilePersistenceFixtures.alphaDetectedAtKey
        )
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName, clearsDomain: false)
        )

        let profile = try #require(await repository.loadProfile())
        let verificationDefaults = makeDefaults(suiteName: suiteName, clearsDomain: false)

        #expect(profile.vin == BikeProfilePersistenceFixtures.vin)
        #expect(profile.declaredPowerTier == .standard)
        #expect(profile.alphaEvidence == [.powerAboveStandard])
        #expect(profile.alphaDetectedAt == BikeProfilePersistenceFixtures.detectedAt)
        #expect(
            verificationDefaults.string(forKey: BikeProfilePersistenceFixtures.declaredPowerTierKey)
                == "future-tier"
        )
        #expect(
            verificationDefaults.stringArray(forKey: BikeProfilePersistenceFixtures.alphaEvidenceKey)
                == [BikeAlphaEvidence.powerAboveStandard.rawValue, "future-evidence"]
        )
        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Broadcasts profile changes to every observer")
    func broadcastsProfileChanges() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        let firstStream = await repository.observeProfile()
        let secondStream = await repository.observeProfile()
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        #expect(await firstIterator.next() == BikeProfileState(profile: nil))
        #expect(await secondIterator.next() == BikeProfileState(profile: nil))

        await repository.saveProfile(BikeProfilePersistenceFixtures.profile)

        let expected = BikeProfileState(profile: BikeProfilePersistenceFixtures.profile)
        #expect(await firstIterator.next() == expected)
        #expect(await secondIterator.next() == expected)
        clearUserDefaults(suiteName: suiteName)
    }

    @Test("A delayed observer receives only the latest pending profile")
    func delayedObserverReceivesLatestProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(
            userDefaults: makeDefaults(suiteName: suiteName)
        )
        let stream = await repository.observeProfile()
        await repository.saveProfile(.init(vin: "FENRTEST000000001"))
        let expected = BikeProfile(vin: "FENRTEST000000002", declaredPowerTier: .alpha)
        await repository.saveProfile(expected)
        var iterator = stream.makeAsyncIterator()

        #expect(await iterator.next() == BikeProfileState(profile: expected))
        clearUserDefaults(suiteName: suiteName)
    }

    nonisolated private func makeSuiteName() -> String {
        "fenr.bike-profile.tests.\(UUID().uuidString)"
    }

    nonisolated private func makeDefaults(
        suiteName: String,
        clearsDomain: Bool = true
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        if clearsDomain {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    nonisolated private func clearUserDefaults(suiteName: String) {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }
}
