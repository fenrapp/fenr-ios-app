import SettingsDomain

public struct DashboardCardSettingsUseCases: Sendable {
    let loadSettings: LoadAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let updateSettings: UpdateAppSettingsUseCase

    public init(
        loadSettings: LoadAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        updateSettings: UpdateAppSettingsUseCase
    ) {
        self.loadSettings = loadSettings
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
    }
}
