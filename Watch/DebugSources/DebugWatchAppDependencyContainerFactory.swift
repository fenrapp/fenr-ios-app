import BikeDomain
import BikeEmulator

@MainActor
enum DebugWatchAppDependencyContainerFactory {
    static func makeDefault() -> WatchAppDependencyContainer {
        let repository = BikeEmulatorRepository()
        return WatchAppDependencyContainer(
            repository: repository,
            profileRepository: WatchDebugProfileRepository(),
            initialProfile: BikeProfile(vin: BikeEmulatorIdentity.vin)
        )
    }
}

private actor WatchDebugProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? { BikeProfile(vin: BikeEmulatorIdentity.vin) }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}
