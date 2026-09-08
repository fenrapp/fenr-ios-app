import BikeDomain
import SettingsDomain

public struct PowerModeSettingsUseCases: Sendable {
    let observeSettings: ObserveAppSettingsUseCase
    let updateSettings: UpdateAppSettingsUseCase
    let refreshPowerModes: RefreshBikePowerModesUseCase
    let preparePowerModeControl: PrepareBikePowerModeControlUseCase
    let setPowerModeConfiguration: SetBikePowerModeConfigurationUseCase
    let prepareTractionControl: PrepareBikeTractionControlUseCase
    let setTractionControlConfiguration: SetBikeTractionControlConfigurationUseCase

    public init(
        observeSettings: ObserveAppSettingsUseCase,
        updateSettings: UpdateAppSettingsUseCase,
        refreshPowerModes: RefreshBikePowerModesUseCase,
        preparePowerModeControl: PrepareBikePowerModeControlUseCase,
        setPowerModeConfiguration: SetBikePowerModeConfigurationUseCase,
        prepareTractionControl: PrepareBikeTractionControlUseCase,
        setTractionControlConfiguration: SetBikeTractionControlConfigurationUseCase
    ) {
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.refreshPowerModes = refreshPowerModes
        self.preparePowerModeControl = preparePowerModeControl
        self.setPowerModeConfiguration = setPowerModeConfiguration
        self.prepareTractionControl = prepareTractionControl
        self.setTractionControlConfiguration = setTractionControlConfiguration
    }
}
