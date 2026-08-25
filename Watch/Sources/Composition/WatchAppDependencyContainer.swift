import AppSettings
import BikeDomain
import Foundation
import RuntimeConfiguration
import SettingsDomain
import WatchDashboard
import WatchOnboarding

@MainActor
struct WatchAppDependencyContainer {
    let repository: any BikeRepository & BikeBatteryHealthRepository & BikeDiscoveryRepository
    let profileRepository: any BikeProfileRepository
    let settingsRepository: any AppSettingsRepository
    let initialProfile: BikeProfile?

    func makeRootDependencies() -> WatchRootDependencies {
        let sessionController = WatchBikeSessionController(repository: repository)
        let setupController = WatchSetupController(
            sessionController: sessionController,
            profileRepository: profileRepository,
            initialProfile: initialProfile
        )
        return WatchRootDependencies(
            dashboardViewModel: makeDashboardViewModel(),
            onboardingViewModel: makeOnboardingViewModel { _ in
                setupController.complete()
            },
            settingsViewModel: makeSettingsViewModel(),
            setupController: setupController
        )
    }

    func makeDashboardViewModel() -> WatchDashboardViewModel {
        WatchDashboardViewModel(
            useCases: .init(
                repository: repository,
                batteryHealthRepository: repository,
                settingsRepository: settingsRepository
            ),
            mapper: WatchDashboardMapperFactory.make(
                locale: .autoupdatingCurrent,
                now: Date.init,
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval
            ),
            maximumDebugEvents: 12
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
            ),
            mapper: AppSettingsViewStateMapper()
        )
    }
}
