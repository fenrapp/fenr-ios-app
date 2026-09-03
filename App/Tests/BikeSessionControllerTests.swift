import BikeDomain
import Testing
import TestSupport

@MainActor
@Suite("Bike session controller")
struct BikeSessionControllerTests {
    @Test("Starts and stops the shared BLE repository only once")
    func managesSingleRepositoryLifecycle() async {
        let repository = SessionSpyRepository()
        let controller = makeController(repository: repository)

        await controller.start()
        await controller.start()
        await controller.stop()
        await controller.stop()

        #expect(await repository.startCount() == 1)
        #expect(await repository.stopCount() == 1)
    }

    @Test("Reconnects through the shared repository")
    func reconnectsAutomaticallyWithConfiguredVIN() async {
        let repository = SessionSpyRepository()
        let controller = makeController(repository: repository)

        await controller.start()
        await controller.connectAutomatically(vin: "FENRTEST000000001")

        #expect(await repository.lastVIN() == "FENRTEST000000001")
    }

    @Test("Deduplicates dashboard retries through the shared repository")
    func deduplicatesDashboardRetries() async {
        let repository = SessionSpyRepository()
        await repository.blockNextConnection()
        let controller = makeController(repository: repository)
        await controller.start()

        controller.retryConnection(vin: "FENRTEST000000001")
        controller.retryConnection(vin: "FENRTEST000000001")

        #expect(await waitUntil { await repository.hasPendingConnection() })
        #expect(await repository.connectionCount() == 1)
        await repository.resumeConnection()
    }

    @Test("Stopping during start leaves the bike repository stopped")
    func stopDuringStartLeavesBikeRepositoryStopped() async {
        let repository = SessionSpyRepository()
        await repository.blockNextStart()
        let controller = makeController(repository: repository)
        let startTask = Task { await controller.start() }

        #expect(await waitUntil { await repository.hasPendingStart() })
        let stopTask = Task { await controller.stop() }
        await repository.resumeStart()
        await startTask.value
        await stopTask.value

        #expect(await repository.startCount() == 1)
        #expect(await repository.stopCount() == 1)
    }

    private func makeController(repository: any BikeRepository) -> BikeSessionController {
        BikeSessionController(
            useCases: .init(
                startRepository: .init(repository: repository),
                stopRepository: .init(repository: repository),
                connectToBike: .init(repository: repository),
                disconnectFromBike: .init(repository: repository)
            )
        )
    }
}
