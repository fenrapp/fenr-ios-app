public protocol BikeProfileRepository: Sendable {
    func loadProfile() async -> BikeProfile?
    func saveProfile(_ profile: BikeProfile) async
    func clearProfile() async
    func observeProfile() async -> AsyncStream<BikeProfileState>
}

public extension BikeProfileRepository {
    func observeProfile() async -> AsyncStream<BikeProfileState> {
        let profile = await loadProfile()
        return AsyncStream { continuation in
            continuation.yield(BikeProfileState(profile: profile))
            continuation.finish()
        }
    }
}
