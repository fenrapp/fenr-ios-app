import BikeDomain
import TestSupport

actor ControllableBikeProfileRepository: BikeProfileRepository {
    private let profileHub = TestEventHub<BikeProfileState>(bufferingPolicy: .bufferingNewest(1))
    private let saveStartedHub = TestEventHub<BikeProfile>(bufferingPolicy: .unbounded)
    private var profile: BikeProfile?
    private var shouldBlockSaves = false
    private var saveWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var savedProfiles: [BikeProfile] = []

    init(profile: BikeProfile?) {
        self.profile = profile
    }

    func loadProfile() -> BikeProfile? {
        profile
    }

    func saveProfile(_ profile: BikeProfile) async {
        savedProfiles.append(profile)
        await saveStartedHub.send(profile)
        if shouldBlockSaves {
            await withCheckedContinuation { continuation in
                saveWaiters.append(continuation)
            }
        }
        self.profile = profile
        await profileHub.send(.init(profile: profile))
    }

    func clearProfile() async {
        profile = nil
        await profileHub.send(.init(profile: nil))
    }

    func observeProfile() async -> AsyncStream<BikeProfileState> {
        await profileHub.stream(replay: .init(profile: profile))
    }

    func observeSaveStarts() async -> AsyncStream<BikeProfile> {
        await saveStartedHub.stream()
    }

    func waitForProfileSubscriber() async -> Bool {
        await profileHub.waitForSubscriber()
    }

    func setShouldBlockSaves(_ shouldBlock: Bool) {
        shouldBlockSaves = shouldBlock
    }

    func releaseNextSave() {
        guard !saveWaiters.isEmpty else { return }
        saveWaiters.removeFirst().resume()
    }
}
