import BikeDomain
import DashboardCardSettings
import SettingsDomain

@MainActor
struct DashboardCardSettingsDependencyContainer {
    func makeViewModel(
        settingsRepository: any AppSettingsRepository,
        bikeLockCapabilityStore: any BikeLockCapabilityStateStoring
    ) -> DashboardCardSettingsViewModel {
        DashboardCardSettingsViewModel(
            useCases: .init(
                loadSettings: .init(repository: settingsRepository),
                observeSettings: .init(repository: settingsRepository),
                updateSettings: .init(repository: settingsRepository)
            ),
            mapper: DashboardCardSettingsViewStateMapper(),
            bikeLockCapabilityStore: bikeLockCapabilityStore
        )
    }
}
