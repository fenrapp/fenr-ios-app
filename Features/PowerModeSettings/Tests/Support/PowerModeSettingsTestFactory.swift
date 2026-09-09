import BikeDomain
import Foundation
@testable import PowerModeSettings
import VehicleSession

@MainActor
func makePowerModeSettingsFixture(
    bikeRepository: PowerModeSettingsBikeRepository = .init(),
    repository: PowerModeSettingsRepository = .init()
) -> PowerModeSettingsTestFixture {
    let vehicleSession = PowerModeSettingsVehicleSession()
    return PowerModeSettingsTestFixture(
        viewModel: PowerModeFeatureFactory.make(
            vehicleSession: vehicleSession,
            basicUseCases: .init(
                tractionCompatibility: .init(repository: bikeRepository),
                applyUserTraction: .init(repository: bikeRepository),
                observeSettings: .init(repository: repository),
                updateSettings: .init(repository: repository),
                refreshPowerModes: .init(repository: bikeRepository),
                preparePowerModeControl: .init(repository: bikeRepository),
                setPowerModeConfiguration: .init(repository: bikeRepository)
            ),
            advancedUseCases: .init(editing: nil, calibration: BikePowerCurveCalibrationFactory.makeDefault()),
            locale: Locale(identifier: "en_US"), makePresetID: UUID.init
        ).basic,
        vehicleSession: vehicleSession,
        repository: repository,
        bikeRepository: bikeRepository
    )
}
struct PowerModeSettingsTestFixture {
    let viewModel: PowerModeSettingsViewModel
    let vehicleSession: PowerModeSettingsVehicleSession
    let repository: PowerModeSettingsRepository
    let bikeRepository: PowerModeSettingsBikeRepository
}
