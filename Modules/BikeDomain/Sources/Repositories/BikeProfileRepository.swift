public protocol BikeProfileRepository: Sendable {
    func loadProfile() async -> BikeProfile?
    func saveProfile(_ profile: BikeProfile) async
    func clearProfile() async
}
