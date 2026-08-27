import BikeDomain
import Combine

struct BikeSessionControllerUseCases {
    let startRepository: StartBikeRepositoryUseCase
    let stopRepository: StopBikeRepositoryUseCase
    let connectToBike: ConnectToBikeUseCase
    let disconnectFromBike: DisconnectBikeUseCase
}

@MainActor
final class BikeSessionController: ObservableObject {
    private let useCases: BikeSessionControllerUseCases
    private var isRunning = false

    init(useCases: BikeSessionControllerUseCases) {
        self.useCases = useCases
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        await useCases.startRepository.execute()
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        await useCases.stopRepository.execute()
    }

    func connectAutomatically(vin: String) async {
        do {
            try await useCases.connectToBike.execute(vin: vin)
        } catch is CancellationError {
            return
        } catch {
            // Connection state exposes a recoverable error to the dashboard and Diagnostics.
        }
    }

    func disconnect() async {
        do {
            try await useCases.disconnectFromBike.execute()
        } catch is CancellationError {
            return
        } catch {
            // A disconnected repository has already reached the intended end state.
        }
    }
}
