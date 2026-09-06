import BikeDomain

struct BikeSessionControllerUseCases {
    let startRepository: StartBikeRepositoryUseCase
    let stopRepository: StopBikeRepositoryUseCase
    let connectToBike: ConnectToBikeUseCase
    let disconnectFromBike: DisconnectBikeUseCase
}

@MainActor
final class BikeSessionController {
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
    private var connectionTask: Task<Void, Never>?

    init(useCases: BikeSessionControllerUseCases) {
        self.useCases = useCases
    }

    deinit {
        startTask?.cancel()
        stopTask?.cancel()
        connectionTask?.cancel()
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
            connectionTask?.cancel()
            let pendingStart = startTask
            let pendingConnection = connectionTask
            let task = Task { [useCases] in
                await pendingStart?.value
                await pendingConnection?.value
                await useCases.stopRepository.execute()
            }
            stopTask = task
            await task.value
            startTask = nil
            connectionTask = nil
            stopTask = nil
            state = .stopped
        }
    }

    func stopIncludingOnboarding() async {
        await stop()
        // Onboarding can start the same repository before this controller starts.
        await useCases.stopRepository.execute()
    }

    func connectAutomatically(vin: String) async {
        guard let task = startConnectionIfNeeded(vin: vin) else { return }
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func retryConnection(vin: String) {
        _ = startConnectionIfNeeded(vin: vin)
    }

    func disconnect() async {
        connectionTask?.cancel()
        await connectionTask?.value
        connectionTask = nil
        do {
            try await useCases.disconnectFromBike.execute()
        } catch is CancellationError {
            return
        } catch {
            // A disconnected repository has already reached the intended end state.
        }
    }
}

private extension BikeSessionController {
    func startConnectionIfNeeded(vin: String) -> Task<Void, Never>? {
        guard state == .started else { return nil }
        if let connectionTask { return connectionTask }
        let task = Task { [weak self, useCases] in
            defer { self?.connectionTask = nil }
            do {
                try await useCases.connectToBike.execute(vin: vin)
            } catch is CancellationError {
                return
            } catch {
                // Connection state exposes a recoverable error to the dashboard and Diagnostics.
            }
        }
        connectionTask = task
        return task
    }
}
