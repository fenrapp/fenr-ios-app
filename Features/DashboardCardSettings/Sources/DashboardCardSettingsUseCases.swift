import SettingsDomain

public struct DashboardCardSettingsUseCases: Sendable {
    let loadSettings: LoadAppSettingsUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let saveSettings: SaveAppSettingsUseCase

    public init(
        loadSettings: LoadAppSettingsUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        saveSettings: SaveAppSettingsUseCase
    ) {
        self.loadSettings = loadSettings
        self.observeSettings = observeSettings
        self.saveSettings = saveSettings
    }
}
