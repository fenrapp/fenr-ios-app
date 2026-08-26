@testable import BikeData
import BikeDomain
import Foundation
import Testing

@Suite("UserDefaults bike profile repository")
struct UserDefaultsBikeProfileRepositoryTests {
    @Test("Loads an empty profile when no bike has completed onboarding")
    func loadsEmptyProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(suiteName: suiteName)

        #expect(await repository.loadProfile() == nil)

        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Persists a configured bike profile")
    func savesAndReloadsProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(suiteName: suiteName)
        let profile = BikeProfile(vin: "UDUSMTEST00000001")

        await repository.saveProfile(profile)

        let reloadedRepository = UserDefaultsBikeProfileRepository(suiteName: suiteName)
        #expect(await reloadedRepository.loadProfile() == profile)
        #expect(await reloadedRepository.loadProfile()?.variant == .sm)

        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Clears the configured bike profile")
    func clearsProfile() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(suiteName: suiteName)
        await repository.saveProfile(.init(vin: "FENRTEST000000001"))

        await repository.clearProfile()

        #expect(await repository.loadProfile() == nil)

        clearUserDefaults(suiteName: suiteName)
    }

    @Test("Persists declared tier and positive Alpha evidence by VIN")
    func persistsPowerTierEvidence() async {
        let suiteName = makeSuiteName()
        let repository = UserDefaultsBikeProfileRepository(suiteName: suiteName)
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
        let repository = UserDefaultsBikeProfileRepository(suiteName: suiteName)
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

    private func makeSuiteName() -> String {
        "fenr.bike-profile.tests.\(UUID().uuidString)"
    }

    private func clearUserDefaults(suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
