import BikeDomain

actor ControllableBikeProfileRepository: BikeProfileRepository {
    private var profile: BikeProfile?
    private(set) var savedProfiles: [BikeProfile] = []
    private(set) var clearCount = 0

    init(profile: BikeProfile? = nil) {
        self.profile = profile
    }

    func loadProfile() -> BikeProfile? {
        profile
    }

    func saveProfile(_ profile: BikeProfile) {
        self.profile = profile
        savedProfiles.append(profile)
    }

    func clearProfile() {
        profile = nil
        clearCount += 1
    }
}
