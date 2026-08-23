import BikeData
import BikeDomain
import BikeSDK
import WatchDashboard

@MainActor
struct WatchAppDependencyContainer {
    let repository: any BikeRepository & BikeBatteryHealthRepository & BikeDiscoveryRepository
    let profileRepository: any BikeProfileRepository
    let initialProfile: BikeProfile?

    static func makeLive() -> WatchAppDependencyContainer {
        let client = BikeTelemetryClientFactory.makeDefault()
        return WatchAppDependencyContainer(
            repository: LiveBikeRepositoryFactory.makeDefault(client: client),
            profileRepository: UserDefaultsBikeProfileRepository(),
            initialProfile: nil
        )
    }

    func makeDashboardViewModel() -> WatchDashboardViewModel {
        WatchDashboardViewModel(
            useCases: .init(repository: repository, batteryHealthRepository: repository)
        )
    }

    func makeOnboardingViewModel(onCompleted: @escaping @MainActor (BikeProfile) -> Void) -> WatchOnboardingViewModel {
        WatchOnboardingViewModel(
            repository: repository,
            discoveryRepository: repository,
            profileRepository: profileRepository,
            onCompleted: onCompleted
        )
    }
}
