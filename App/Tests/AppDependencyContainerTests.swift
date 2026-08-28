@testable import BatteryHealth
import BikeDomain
import BLETraceDomain
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("App dependency container")
struct AppDependencyContainerTests {
    @Test("Container builds diagnostics graph without starting streams")
    func buildsBikeDiagnosticsGraph() {
        let container = ProductionAppDependencyContainerFactory.makeDefault()
        let viewModel = container.makeRootDependencies().diagnosticsViewModel

        #expect(viewModel.viewState.vin.isEmpty)
        #expect(!viewModel.viewState.isConnectEnabled)
        #expect(viewModel.viewState.debugEvents.isEmpty)
    }

    @Test("Container assembles root dependencies before the view is created")
    func buildsRootDependencies() {
        let dependencies = ProductionAppDependencyContainerFactory.makeDefault().makeRootDependencies()
        let rideDashboard = dependencies.rideDashboardFactory.makeFeature()

        #expect(!dependencies.setupFlow.isLoaded)
        #expect(!rideDashboard.dashboardViewModel.viewState.hasTelemetry)
        #expect(!rideDashboard.chargingViewModel.viewState.control.isEnabled)
        #expect(dependencies.rideDashboardFactory.makeFeature() !== rideDashboard)
    }

    @Test("Composable containers build independently")
    func composableContainersBuildIndependently() {
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let diagnosticsContainer = BikeDiagnosticsDependencyContainer()
        let traceRepository = NoOpBLETraceRepository()

        let client = bikeSDKContainer.makeBikeTelemetryClient(traceRecorder: traceRepository)
        let repository = bikeDataContainer.makeBikeRepository(client: client)
        let pinDeriver = bikeDataContainer.makeBikePinDeriver()
        let profileRepository = EmptyBikeProfileRepository()
        let viewModel = diagnosticsContainer.makeBikeDiagnosticsViewModel(
            repository: repository,
            pinDeriver: pinDeriver,
            profileRepository: profileRepository,
            settingsRepository: EmptyAppSettingsRepository(),
            bleTraceLogRepository: traceRepository
        )

        #expect(viewModel.viewState.connection.status == "Idle")
        #expect(viewModel.viewState.metrics.isEmpty)
    }

    @Test("Lifecycle starts shared sessions before the BLE repository")
    func lifecycleStartsSharedSessions() async {
        let fixture = AppLifecycleControllerFixture()

        await fixture.lifecycleController.start()

        #expect(await fixture.vehicleSession.startCount() == 1)
        #expect(await fixture.rideSession.recordedEvents() == ["start"])
        #expect(await fixture.repository.startCount() == 1)
        #expect(await fixture.repository.lastVIN() == "FENRTEST000000001")
    }

    @Test("Lifecycle prepares traces in parallel and waits before automatic BLE start")
    func lifecycleWaitsForTracePreparationBeforeBLEStart() async {
        let tracePreparer = LifecycleBLETraceStoragePreparer()
        let fixture = AppLifecycleControllerFixture(
            bleTraceStoragePreparer: tracePreparer
        )
        let startTask = Task { await fixture.lifecycleController.start() }

        #expect(await waitUntil { await tracePreparer.preparationHasStarted() })
        #expect(await fixture.vehicleSession.startCount() == 1)
        #expect(await fixture.repository.startCount() == 0)

        await tracePreparer.finishPreparation()
        await startTask.value
        #expect(await fixture.repository.startCount() == 1)
    }

    @Test("Lifecycle waits for pending persistence before shutdown barriers")
    func lifecycleWaitsForPendingPersistence() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.lifecycleController.start()
        await fixture.rideSession.delayNextPersistence()

        fixture.lifecycleController.persistRideSession()
        fixture.lifecycleController.stop()
        try? await Task.sleep(for: .milliseconds(180))

        #expect(await fixture.rideSession.recordedEvents() == [
            "start",
            "persist",
            "complete",
            "flush",
            "stop"
        ])
        #expect(await fixture.vehicleSession.stopCount() == 1)
        #expect(await fixture.repository.stopCount() == 1)
    }
}
