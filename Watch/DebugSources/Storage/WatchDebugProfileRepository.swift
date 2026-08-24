import BikeDomain
import BikeEmulator

actor WatchDebugProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? { BikeProfile(vin: BikeEmulatorIdentity.vin) }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}
