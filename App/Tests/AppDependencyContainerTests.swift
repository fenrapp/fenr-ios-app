@testable import BatteryHealth
import BikeDomain
import BLETraceDomain
import MaintenanceLog
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@MainActor
@Suite("App dependency container")
struct AppDependencyContainerTests {
    @Test("Container builds diagnostics graph without starting streams")
    func buildsBikeDiagnosticsGraph() throws {
        let container = try makeContainer()
        let viewModel = container.makeRootDependencies().featureStore.diagnosticsViewModel

        #expect(viewModel.viewState.vin == "--")
        #expect(!viewModel.viewState.isReconnectEnabled)
        #expect(viewModel.viewState.debugEvents.isEmpty)
        #expect(!viewModel.isPresentationActive)
    }

    @Test("Container assembles root dependencies before the view is created")
    func buildsRootDependencies() throws {
        let dependencies = try makeContainer().makeRootDependencies()
        let rideDashboard = dependencies.featureStore.rideDashboardFactory.makeFeature()

        #expect(!dependencies.setupFlow.isLoaded)
        #expect(!rideDashboard.dashboardViewModel.viewState.hasTelemetry)
        #expect(!rideDashboard.chargingViewModel.viewState.control.isEnabled)
        #expect(dependencies.featureStore.rideDashboardFactory.makeFeature() !== rideDashboard)
    }

    @Test("Composable containers build independently")
    func composableContainersBuildIndependently() {
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let diagnosticsContainer = BikeDiagnosticsDependencyContainer()
        let traceRepository = NoOpBLETraceRepository()

        let client = bikeSDKContainer.makeBikeTelemetryClient(
            traceRecorder: traceRepository, captureState: BLETraceCaptureState()
        )
        let repository = bikeDataContainer.makeBikeRepository(client: client)
        let viewModel = diagnosticsContainer.makeBikeDiagnosticsViewModel(
            repository: repository,
            vehicleSession: LifecycleVehicleSessionSpy(),
            bleTraceLogRepository: traceRepository
        )

        #expect(viewModel.viewState.connection.status == "Idle")
        #expect(viewModel.viewState.metrics.allSatisfy { $0.value == "--" })
        #expect(!viewModel.isPresentationActive)
    }

    private func makeContainer() throws -> AppDependencyContainer {
        try ProductionAppDependencyContainerFactory.makeDefault(
            maintenanceReminderScheduler: NoOpMaintenanceReminderScheduler()
        )
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

    @Test("Lifecycle retries with the configured bike through the shared session")
    func lifecycleRetriesConfiguredBike() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.lifecycleController.start()

        fixture.lifecycleController.retryConnection()

        #expect(await waitUntil { await fixture.repository.connectionCount() == 2 })
        #expect(await fixture.repository.lastVIN() == "FENRTEST000000001")
    }

    @Test("Lifecycle starts BLE without preparing diagnostics storage")
    func lifecycleStartsWithoutDiagnosticsPreparation() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.lifecycleController.start()
        #expect(await fixture.repository.startCount() == 1)
        #expect(await fixture.repository.captureStopCount() == 0)
    }

    @Test("Lifecycle waits for pending persistence before shutdown barriers")
    func lifecycleWaitsForPendingPersistence() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.lifecycleController.start()
        await fixture.rideSession.delayNextPersistence()

        fixture.lifecycleController.persistRideSession()
        fixture.lifecycleController.stop()
        #expect(await waitUntil { await fixture.rideSession.hasPendingPersistence() })
        #expect(await fixture.rideSession.recordedEvents() == ["start"])
        #expect(await fixture.vehicleSession.stopCount() == 0)
        #expect(await fixture.repository.stopCount() == 0)

        await fixture.rideSession.resumePersistence()
        #expect(await waitUntil {
            let events = await fixture.rideSession.recordedEvents()
            let vehicleStopCount = await fixture.vehicleSession.stopCount()
            let repositoryStopCount = await fixture.repository.stopCount()
            return events == ["start", "persist", "stop"]
                && vehicleStopCount == 1
                && repositoryStopCount == 1
        })

        #expect(await fixture.rideSession.recordedEvents() == ["start", "persist", "stop"])
        #expect(await fixture.vehicleSession.stopCount() == 1)
        #expect(await fixture.repository.stopCount() == 1)
    }

    @Test("Changing bikes stops and restarts the existing ride session")
    func changeBikeStopsAndRestartsRideSessionAroundDisconnect() async {
        let fixture = AppLifecycleControllerFixture()
        let rideSession = fixture.rideSession
        let vehicleSession = fixture.vehicleSession
        var completionCount = 0
        await fixture.lifecycleController.start()

        fixture.lifecycleController.changeBike {
            completionCount += 1
        }

        #expect(await waitUntil {
            await rideSession.recordedEvents() == ["start", "stop", "start"]
                && completionCount == 1
        })
        #expect(rideSession === fixture.rideSession)
        #expect(vehicleSession === fixture.vehicleSession)
        #expect(await rideSession.recordedEvents() == ["start", "stop", "start"])
        #expect(await vehicleSession.startCount() == 1)
        #expect(await fixture.repository.startCount() == 1)
        #expect(completionCount == 1)
        #expect(await fixture.repository.captureStopCount() == 1)
    }

    @Test("Stopping during repository startup rolls back started services")
    func lifecycleStopDuringStartupRollsBackInReverseOrder() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.repository.blockNextStart()
        let startTask = Task { await fixture.lifecycleController.start() }
        #expect(await waitUntil { await fixture.repository.hasPendingStart() })
        fixture.lifecycleController.stop()
        await fixture.repository.resumeStart()
        await startTask.value
        #expect(await waitUntil {
            let rideEvents = await fixture.rideSession.recordedEvents()
            let vehicleStopCount = await fixture.vehicleSession.stopCount()
            return rideEvents == ["start", "stop"] && vehicleStopCount == 1
        })
        #expect(await fixture.repository.startCount() == 1)
        #expect(await fixture.repository.stopCount() == 1)
    }

    @Test("Lifecycle restarts after shutdown completes")
    func lifecycleRestartsAfterShutdownCompletes() async {
        let fixture = AppLifecycleControllerFixture()
        await fixture.lifecycleController.start()
        fixture.lifecycleController.stop()
        #expect(await waitUntil { await fixture.repository.stopCount() == 1 })

        await fixture.lifecycleController.start()

        #expect(await fixture.vehicleSession.startCount() == 2)
        #expect(await fixture.rideSession.recordedEvents() == ["start", "stop", "start"])
        #expect(await fixture.repository.startCount() == 2)
    }

    @Test("Scheduled shutdown finishes after the composition root is released")
    func scheduledShutdownOutlivesCompositionRoot() async throws {
        var fixture: AppLifecycleControllerFixture? = AppLifecycleControllerFixture()
        let repository = try #require(fixture?.repository)
        let rideSession = try #require(fixture?.rideSession)
        let vehicleSession = try #require(fixture?.vehicleSession)
        weak var controller = fixture?.lifecycleController
        await fixture?.lifecycleController.start()

        fixture?.lifecycleController.stop()
        fixture = nil

        #expect(await waitUntil { await repository.stopCount() == 1 })
        #expect(await rideSession.recordedEvents() == ["start", "stop"])
        #expect(await vehicleSession.stopCount() == 1)
        #expect(await waitUntil { controller == nil })
    }

    @Test("Lifecycle awaits startup preparation before starting sessions")
    func lifecycleAwaitsStartupPreparationBeforeStartingSessions() async {
        let preparer = ControllableAppStartupPreparer()
        await preparer.blockNextPreparation()
        let fixture = AppLifecycleControllerFixture(startupPreparer: preparer)
        let startTask = Task { await fixture.lifecycleController.start() }

        #expect(await waitUntil { await preparer.hasPendingPreparation() })
        #expect(await fixture.vehicleSession.startCount() == 0)
        #expect(await fixture.rideSession.recordedEvents().isEmpty)
        #expect(await fixture.repository.startCount() == 0)

        await preparer.resumePreparation()
        await startTask.value
        #expect(await fixture.vehicleSession.startCount() == 1)
        #expect(await fixture.repository.startCount() == 1)
    }
}
