public protocol BikeProfileRepository: Sendable {
    func loadProfile() async -> BikeProfile?
    func saveProfile(_ profile: BikeProfile) async
    func clearProfile() async
    func observeProfile() async -> AsyncStream<BikeProfile?>
}

public extension BikeProfileRepository {
    func observeProfile() async -> AsyncStream<BikeProfile?> {
        let profile = await loadProfile()
        return AsyncStream { continuation in
            continuation.yield(profile)
            continuation.finish()
        }
    }
}
