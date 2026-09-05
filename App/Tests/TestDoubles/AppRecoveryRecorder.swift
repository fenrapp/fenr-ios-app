import Foundation

@MainActor
final class AppRecoveryRecorder {
    var failingStore: String?
    var failsRealExperience = true
    private(set) var openedStores: [String] = []
    private(set) var realAttempts = 0

    func open(_ store: String) throws {
        openedStores.append(store)
        if failingStore == store { throw AppExperienceFailure.storage }
    }

    func buildReal() throws {
        realAttempts += 1
        if failsRealExperience { throw AppExperienceFailure.storage }
    }
}
