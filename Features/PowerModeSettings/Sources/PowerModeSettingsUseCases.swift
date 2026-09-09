import BikeDomain
import SettingsDomain

public struct PowerModeSettingsUseCases: Sendable {
    let tractionCompatibility: ReadBikeTractionCompatibilityUseCase
    let applyUserTraction: ApplyUserBikeTractionControlConfigurationUseCase
    let observeSettings: ObserveAppSettingsUseCase
    let updateSettings: UpdateAppSettingsUseCase
    let refreshPowerModes: RefreshBikePowerModesUseCase
    let preparePowerModeControl: PrepareBikePowerModeControlUseCase
    let setPowerModeConfiguration: SetBikePowerModeConfigurationUseCase

    public init(
        tractionCompatibility: ReadBikeTractionCompatibilityUseCase,
        applyUserTraction: ApplyUserBikeTractionControlConfigurationUseCase,
        observeSettings: ObserveAppSettingsUseCase,
        updateSettings: UpdateAppSettingsUseCase,
        refreshPowerModes: RefreshBikePowerModesUseCase,
        preparePowerModeControl: PrepareBikePowerModeControlUseCase,
        setPowerModeConfiguration: SetBikePowerModeConfigurationUseCase
    ) {
        self.tractionCompatibility = tractionCompatibility
        self.applyUserTraction = applyUserTraction
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.refreshPowerModes = refreshPowerModes
        self.preparePowerModeControl = preparePowerModeControl
        self.setPowerModeConfiguration = setPowerModeConfiguration
    }
}
