import BikeDomain
import Foundation

public actor UserDefaultsBikeProfileRepository: BikeProfileRepository {
    private enum Constants {
        static let profileVINKey = "com.fenr.bikeProfile.vin"
    }

    private let userDefaults: UserDefaults

    public init() {
        userDefaults = .standard
    }

    init(suiteName: String) {
        userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public func loadProfile() -> BikeProfile? {
        userDefaults.string(forKey: Constants.profileVINKey).map(BikeProfile.init(vin:))
    }

    public func saveProfile(_ profile: BikeProfile) {
        userDefaults.set(profile.vin, forKey: Constants.profileVINKey)
    }

    public func clearProfile() {
        userDefaults.removeObject(forKey: Constants.profileVINKey)
    }
}
