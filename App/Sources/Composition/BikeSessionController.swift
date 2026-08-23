import BikeDomain
import Combine
import Foundation

@MainActor
final class BikeSessionController: ObservableObject {
    private let startRepository: StartBikeRepositoryUseCase
    private let stopRepository: StopBikeRepositoryUseCase
    private let connectToBike: ConnectToBikeUseCase
    private let disconnectFromBike: DisconnectBikeUseCase
    private var isRunning = false

    init(repository: BikeRepository) {
        startRepository = StartBikeRepositoryUseCase(repository: repository)
        stopRepository = StopBikeRepositoryUseCase(repository: repository)
        connectToBike = ConnectToBikeUseCase(repository: repository)
        disconnectFromBike = DisconnectBikeUseCase(repository: repository)
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        await startRepository.execute()
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        await stopRepository.execute()
    }

    func connectAutomatically(vin: String) async {
        do {
            try await connectToBike.execute(vin: vin)
        } catch is CancellationError {
            return
        } catch {
            // Connection state exposes a recoverable error to the dashboard and Diagnostics.
        }
    }

    func disconnect() async {
        do {
            try await disconnectFromBike.execute()
        } catch is CancellationError {
            return
        } catch {
            // A disconnected repository has already reached the intended end state.
        }
    }
}
