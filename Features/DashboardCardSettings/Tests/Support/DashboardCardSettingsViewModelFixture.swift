import DashboardCardSettings

@MainActor
struct DashboardCardSettingsViewModelFixture {
    let repository: DashboardCardSettingsRepository
    let capabilityStore: DashboardCardSettingsBikeLockCapabilityStore
    let viewModel: DashboardCardSettingsViewModel

    init(
        repository: DashboardCardSettingsRepository = .init(),
        capabilityStore: DashboardCardSettingsBikeLockCapabilityStore = .init()
    ) {
        self.repository = repository
        self.capabilityStore = capabilityStore
        viewModel = DashboardCardSettingsViewModel(
            useCases: .init(
                loadSettings: .init(repository: repository),
                observeSettings: .init(repository: repository),
                saveSettings: .init(repository: repository)
            ),
            mapper: DashboardCardSettingsViewStateMapper(),
            bikeLockCapabilityStore: capabilityStore
        )
    }
}
