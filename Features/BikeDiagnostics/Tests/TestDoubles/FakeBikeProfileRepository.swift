import BikeDomain

actor FakeBikeProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?

    init(profile: BikeProfile? = nil) {
        self.profile = profile
    }

    func loadProfile() async -> BikeProfile? { profile }
    func saveProfile(_ profile: BikeProfile) async { self.profile = profile }
    func clearProfile() async { profile = nil }
}
