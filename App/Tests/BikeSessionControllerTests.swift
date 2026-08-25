import BikeDomain
import Testing

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

        await controller.connectAutomatically(vin: "FENRTEST000000001")

        #expect(await repository.lastVIN() == "FENRTEST000000001")
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
