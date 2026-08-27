import AppSettings
import BikeDomain
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
        let viewModel = AppSettingsViewModel(
            useCases: makeUseCases(repository: repository),
            mapper: AppSettingsViewStateMapper()
        )

        viewModel.start()
        try? await Task.sleep(for: .milliseconds(10))
        viewModel.selectSpeedSource(id: SpeedSource.hybrid.rawValue)
        viewModel.selectMeasurementSystem(id: MeasurementSystem.imperial.rawValue)
        viewModel.selectBatteryPackCapacity(id: BatteryPackCapacity.sixPointEightKilowattHours.rawValue)
        var expectedSettings = AppSettings(
            speedSource: .hybrid,
            measurementSystem: .imperial
        )
        expectedSettings.setBatteryPackCapacity(
            .sixPointEightKilowattHours,
            forVIN: TestProfileRepository.vin
        )
        let didSave = await waitUntil {
            await repository.settings == expectedSettings
        }

        #expect(didSave)
        viewModel.stop()
    }

    @Test("Publishes controls shaped for direct rendering")
    func publishesPresentationControls() async {
        let repository = SettingsRepository()
        let viewModel = AppSettingsViewModel(
            useCases: makeUseCases(repository: repository),
            mapper: AppSettingsViewStateMapper()
        )

        viewModel.start()
        viewModel.selectSpeedSource(id: SpeedSource.gps.rawValue)
        #expect(await waitUntil {
            viewModel.viewState.speedSource.locationPermission == .authorized
        })

        #expect(viewModel.viewState.speedSource.selection.selectedID == SpeedSource.gps.rawValue)
        #expect(viewModel.viewState.speedSource.selection.options.map(\.title) == ["Bike", "GPS", "GPS+"])
        #expect(viewModel.viewState.speedSource.description.contains("phone GPS"))
        #expect(viewModel.viewState.speedSource.locationPermission == .authorized)
        #expect(viewModel.viewState.measurementSystem.options.map(\.title) == ["System", "Metric", "Imperial"])

        viewModel.selectSpeedSource(id: SpeedSource.motorcycle.rawValue)
        #expect(viewModel.viewState.speedSource.locationPermission == nil)
        viewModel.stop()
    }

    private func makeUseCases(repository: SettingsRepository) -> AppSettingsUseCases {
        .init(
            saveSettings: .init(repository: repository),
            observeSettings: .init(repository: repository),
            locationAuthorizationStatus: .init(repository: repository),
            requestLocationAuthorization: .init(repository: repository),
            loadBikeProfile: .init(repository: TestProfileRepository()),
            observeBikeProfile: .init(repository: TestProfileRepository())
        )
    }

}

private actor TestProfileRepository: BikeProfileRepository {
    static let vin = "TESTVIN0000000001"

    func loadProfile() -> BikeProfile? { .init(vin: Self.vin) }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}
