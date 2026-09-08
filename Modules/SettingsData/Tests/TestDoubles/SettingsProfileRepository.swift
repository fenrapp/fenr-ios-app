import BikeDomain
import TestSupport

actor SettingsProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?
    private let events: TestEventHub<BikeProfileState>
    private var pausesNextLoad = false
    private var loadContinuation: CheckedContinuation<Void, Never>?

    init(profile: BikeProfile?, events: TestEventHub<BikeProfileState>) {
        self.profile = profile
        self.events = events
    }

    func loadProfile() async -> BikeProfile? {
        if pausesNextLoad {
            pausesNextLoad = false
            await withCheckedContinuation { loadContinuation = $0 }
        }
        return profile
    }

    func pauseNextLoad() { pausesNextLoad = true }
    func hasPendingLoad() -> Bool { loadContinuation != nil }
    func resumeLoad() {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func saveProfile(_ profile: BikeProfile) async {
        self.profile = profile
        await events.send(.init(profile: profile))
    }

    func clearProfile() async {
        profile = nil
        await events.send(.init(profile: nil))
    }

    func observeProfile() async -> AsyncStream<BikeProfileState> {
        await events.stream(replay: .init(profile: profile))
    }
}
