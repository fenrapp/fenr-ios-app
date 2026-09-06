import BikeDomain

@MainActor
struct WatchBikeSessionController {
    private let repository: any BikeRepository

    init(repository: any BikeRepository) {
        self.repository = repository
    }

    func start() async {
        await repository.start()
    }

    func connectAutomatically(vin: String) async {
        try? await repository.connect(vin: vin)
    }

    func disconnect() async {
        try? await repository.disconnect()
    }
}
