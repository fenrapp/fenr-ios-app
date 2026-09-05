import BikeDomain
import TestSupport

actor SettingsProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?
    private let events: TestEventHub<BikeProfileState>

    init(profile: BikeProfile?, events: TestEventHub<BikeProfileState>) {
        self.profile = profile
        self.events = events
    }

    func loadProfile() -> BikeProfile? { profile }

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
