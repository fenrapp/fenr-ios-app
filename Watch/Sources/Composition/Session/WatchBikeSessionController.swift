import BikeDomain
import Combine
import Foundation

@MainActor
final class WatchBikeSessionController: ObservableObject {
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

    func stop() async {
        await repository.stop()
    }
}
