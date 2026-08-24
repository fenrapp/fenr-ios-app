import AppSettings
import BikeDomain
import SettingsDomain
import WatchDashboard
import WatchOnboarding

@MainActor
struct WatchAppDependencyContainer {
    let repository: any BikeRepository & BikeBatteryHealthRepository & BikeDiscoveryRepository
    let profileRepository: any BikeProfileRepository
    let settingsRepository: any AppSettingsRepository
    let initialProfile: BikeProfile?

    func makeDashboardViewModel() -> WatchDashboardViewModel {
        WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: settingsRepository
            )
        )
    }

    func makeOnboardingViewModel(onCompleted: @escaping @MainActor (BikeProfile) -> Void) -> WatchOnboardingViewModel {
        WatchOnboardingViewModel(
            useCases: .init(
                connectToBike: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeDebugEvents: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                saveProfile: .init(repository: profileRepository)
            ),
            onCompleted: onCompleted
        )
    }

    func makeSettingsViewModel() -> AppSettingsViewModel {
        AppSettingsViewModel(
            useCases: .init(
                saveSettings: .init(repository: settingsRepository),
                observeSettings: .init(repository: settingsRepository)
            )
        )
    }
}
