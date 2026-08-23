import BikeDomain

actor OnboardingProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?

    func loadProfile() async -> BikeProfile? { profile }
    func saveProfile(_ profile: BikeProfile) async { self.profile = profile }
    func clearProfile() async { profile = nil }
}
