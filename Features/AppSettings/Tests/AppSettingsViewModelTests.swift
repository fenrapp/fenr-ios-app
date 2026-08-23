import AppSettings
import EnvironmentDomain
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("App settings view model")
struct AppSettingsViewModelTests {
    @Test("Saves selected settings")
    func savesSelectedSettings() async {
        let repository = SettingsRepository()
        let viewModel = AppSettingsViewModel(useCases: makeUseCases(repository: repository))

        viewModel.start()
        viewModel.selectSpeedSource(.hybrid)
        viewModel.selectMeasurementSystem(.imperial)
        viewModel.selectBatteryPackCapacity(.sixPointEightKilowattHours)
        let didSave = await waitUntil {
            await repository.settings == .init(
                speedSource: .hybrid,
                measurementSystem: .imperial,
                batteryPackCapacity: .sixPointEightKilowattHours
            )
        }

        #expect(didSave)
        viewModel.stop()
    }

    private func makeUseCases(repository: SettingsRepository) -> AppSettingsUseCases {
        .init(
            loadSettings: .init(repository: repository),
            saveSettings: .init(repository: repository),
            observeSettings: .init(repository: repository),
            locationAuthorizationStatus: .init(repository: repository),
            requestLocationAuthorization: .init(repository: repository)
        )
    }

}
