import BikeDomain
import SettingsDomain

public struct PowerModeSettingsUseCases: Sendable {
    let saveSettings: SaveAppSettingsUseCase
    let refreshPowerModes: RefreshBikePowerModesUseCase
    let preparePowerModeControl: PrepareBikePowerModeControlUseCase
    let setPowerModeConfiguration: SetBikePowerModeConfigurationUseCase
    let prepareTractionControl: PrepareBikeTractionControlUseCase
    let setTractionControlConfiguration: SetBikeTractionControlConfigurationUseCase

    public init(
        saveSettings: SaveAppSettingsUseCase,
        refreshPowerModes: RefreshBikePowerModesUseCase,
        preparePowerModeControl: PrepareBikePowerModeControlUseCase,
        setPowerModeConfiguration: SetBikePowerModeConfigurationUseCase,
        prepareTractionControl: PrepareBikeTractionControlUseCase,
        setTractionControlConfiguration: SetBikeTractionControlConfigurationUseCase
    ) {
        self.saveSettings = saveSettings
        self.refreshPowerModes = refreshPowerModes
        self.preparePowerModeControl = preparePowerModeControl
        self.setPowerModeConfiguration = setPowerModeConfiguration
        self.prepareTractionControl = prepareTractionControl
        self.setTractionControlConfiguration = setTractionControlConfiguration
    }
}
