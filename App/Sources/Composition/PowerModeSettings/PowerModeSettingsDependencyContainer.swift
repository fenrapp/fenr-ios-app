import BikeDomain
import Foundation
import PowerModeSettings
import SettingsDomain
import VehicleSession

@MainActor
struct PowerModeSettingsDependencyContainer {
    func makeViewModel(
        settingsRepository: any AppSettingsRepository,
        bikeRepository: any BikeRepository,
        vehicleSession: any VehicleSessionService
    ) -> PowerModeSettingsViewModel {
        PowerModeSettingsViewModel(
            vehicleSession: vehicleSession,
            useCases: .init(
                saveSettings: .init(repository: settingsRepository),
                refreshPowerModes: .init(repository: bikeRepository),
                preparePowerModeControl: .init(repository: bikeRepository),
                setPowerModeConfiguration: .init(repository: bikeRepository),
                prepareTractionControl: .init(repository: bikeRepository),
                setTractionControlConfiguration: .init(repository: bikeRepository)
            ),
            mapper: PowerModeSettingsViewStateMapper(locale: .autoupdatingCurrent)
        )
    }
}
