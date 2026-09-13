import BikeDomain
import Foundation
import PowerModeSettings
import SettingsDomain
import VehicleSession

@MainActor
struct PowerModeSettingsDependencyContainer {
    let presets: any BikePowerModePresetRepository

    func makeFeature(
        settingsRepository: any AppSettingsRepository,
        bikeRepository: any BikeRepository,
        vehicleSession: any VehicleSessionService
    ) -> PowerModeFeature {
        let calibration = BikePowerCurveCalibrationFactory.makeDefault()
        let advanced = PowerModeAdvancedUseCases(
            editing: bikeRepository.supportsAdvancedPowerModes ? .init(
                repository: bikeRepository,
                presets: presets,
                calibration: calibration
            ) : nil,
            calibration: calibration
        )
        return PowerModeFeatureFactory.make(
            vehicleSession: vehicleSession,
            basicUseCases: .init(
                tractionCompatibility: .init(repository: bikeRepository),
                applyUserTraction: .init(repository: bikeRepository),
                observeSettings: .init(repository: settingsRepository),
                updateSettings: .init(repository: settingsRepository),
                refreshPowerModes: .init(repository: bikeRepository),
                preparePowerModeControl: .init(repository: bikeRepository),
                setPowerModeConfiguration: .init(repository: bikeRepository)
            ),
            advancedUseCases: advanced, locale: .autoupdatingCurrent, makePresetID: UUID.init
        )
    }
}
