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
    private enum State {
        case stopped
        case starting
        case started
        case stopping
    }

    private let useCases: BikeSessionControllerUseCases
    private var state = State.stopped
    private var startTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?

    init(useCases: BikeSessionControllerUseCases) {
        self.useCases = useCases
    }

    deinit {
        startTask?.cancel()
        stopTask?.cancel()
    }

    func start() async {
        switch state {
        case .started:
            return
        case .starting:
            await startTask?.value
        case .stopping:
            await stopTask?.value
            await start()
        case .stopped:
            state = .starting
            let task = Task { [useCases] in
                await useCases.startRepository.execute()
            }
            startTask = task
            await task.value
            guard state == .starting else { return }
            startTask = nil
            state = .started
        }
    }

    func stop() async {
        switch state {
        case .stopped:
            return
        case .stopping:
            await stopTask?.value
        case .starting, .started:
            state = .stopping
            startTask?.cancel()
            let pendingStart = startTask
            let task = Task { [useCases] in
                await pendingStart?.value
                await useCases.stopRepository.execute()
            }
            stopTask = task
            await task.value
            startTask = nil
            stopTask = nil
            state = .stopped
        }
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
