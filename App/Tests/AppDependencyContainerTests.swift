import BikeDomain
import SettingsDomain
import Testing

@MainActor
@Suite("App dependency container")
struct AppDependencyContainerTests {
    @Test("Container builds diagnostics graph without starting streams")
    func buildsBikeDiagnosticsGraph() {
        let container = ProductionAppDependencyContainerFactory.makeDefault()
        let viewModel = container.makeBikeDiagnosticsViewModel()

        #expect(viewModel.viewState.vin.isEmpty)
        #expect(!viewModel.viewState.isConnectEnabled)
        #expect(viewModel.viewState.debugEvents.isEmpty)
    }

    @Test("Composable containers build independently")
    func composableContainersBuildIndependently() {
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let diagnosticsContainer = BikeDiagnosticsDependencyContainer()

        let client = bikeSDKContainer.makeBikeTelemetryClient()
        let repository = bikeDataContainer.makeBikeRepository(client: client)
        let pinDeriver = bikeDataContainer.makeBikePinDeriver()
        let profileRepository = EmptyBikeProfileRepository()
        let viewModel = diagnosticsContainer.makeBikeDiagnosticsViewModel(
            repository: repository,
            pinDeriver: pinDeriver,
            profileRepository: profileRepository,
            settingsRepository: EmptyAppSettingsRepository()
        )

        #expect(viewModel.viewState.connection.status == "Idle")
        #expect(viewModel.viewState.metrics.isEmpty)
    }
}
