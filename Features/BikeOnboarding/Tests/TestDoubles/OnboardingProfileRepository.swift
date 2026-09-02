import BikeDomain

actor OnboardingProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?
    private var saves = 0

    func loadProfile() async -> BikeProfile? { profile }
    func saveProfile(_ profile: BikeProfile) async {
        self.profile = profile
        saves += 1
    }
    func clearProfile() async { profile = nil }
    func saveCount() async -> Int { saves }
}
