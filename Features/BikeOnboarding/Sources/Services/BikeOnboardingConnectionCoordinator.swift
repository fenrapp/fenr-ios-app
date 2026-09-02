import BikeDomain

enum BikeOnboardingConnectionEvent: Sendable {
    case permissionReady
    case telemetry(peripheralName: String?)
    case progress(BikeOnboardingConnectionState)
    case recovery(BikeOnboardingConnectionState)
    case bluetooth(BikeOnboardingBluetoothState)
    case attemptFailed
}

@MainActor
public final class BikeOnboardingConnectionCoordinator {
    let events: AsyncStream<BikeOnboardingConnectionEvent>

    private let repositoryStarter: BikeOnboardingRepositoryStarter
    private let connectToBike: ConnectToBikeUseCase
    private let disconnectBike: DisconnectBikeUseCase
    private let observeConnection: ObserveBikeConnectionUseCase
    private let mapper: BikeOnboardingPresentationMapper
    private let eventContinuation: AsyncStream<BikeOnboardingConnectionEvent>.Continuation

    private var observationTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var disconnectionTask: Task<Void, Never>?

    public init(
        repositoryStarter: BikeOnboardingRepositoryStarter,
        connectToBike: ConnectToBikeUseCase,
        disconnectBike: DisconnectBikeUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        mapper: BikeOnboardingPresentationMapper
    ) {
        self.repositoryStarter = repositoryStarter
        self.connectToBike = connectToBike
        self.disconnectBike = disconnectBike
        self.observeConnection = observeConnection
        self.mapper = mapper
        let eventChannel = AsyncStream<BikeOnboardingConnectionEvent>.makeStream()
        events = eventChannel.stream
        eventContinuation = eventChannel.continuation
    }

    deinit {
        observationTask?.cancel()
        connectionTask?.cancel()
        eventContinuation.finish()
    }

    func startObserving() {
        guard observationTask == nil else { return }
        let observeConnection = observeConnection
        observationTask = Task { [weak self] in
            let connections = await observeConnection.execute()
            for await connection in connections {
                guard !Task.isCancelled else { return }
                self?.receive(connection)
            }
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    func prepareRepository() -> Task<Void, Never> {
        repositoryStarter.start()
    }

    func connect(vin: String, after pendingOperation: Task<Void, Never>?) {
        connectionTask?.cancel()
        let previousDisconnection = disconnectionTask
        let connectToBike = connectToBike
        connectionTask = Task { [weak self] in
            await pendingOperation?.value
            await previousDisconnection?.value
            guard !Task.isCancelled else { return }
            do {
                try await connectToBike.execute(vin: vin)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.eventContinuation.yield(.attemptFailed)
            }
        }
    }

    @discardableResult
    func disconnect(after pendingOperation: Task<Void, Never>? = nil) -> Task<Void, Never> {
        connectionTask?.cancel()
        connectionTask = nil
        let previousDisconnection = disconnectionTask
        let disconnectBike = disconnectBike
        let task = Task {
            await pendingOperation?.value
            await previousDisconnection?.value
            guard !Task.isCancelled else { return }
            try? await disconnectBike.execute()
        }
        disconnectionTask = task
        return task
    }

    private func receive(_ connection: BikeConnection) {
        let event: BikeOnboardingConnectionEvent?
        switch connection.state {
        case .idle:
            event = .permissionReady
        case .receivingTelemetry(let peripheralName):
            event = .telemetry(peripheralName: peripheralName)
        case .failed:
            event = mapper.connectionState(for: connection.state).map(BikeOnboardingConnectionEvent.recovery)
        case .pairingResetRequired, .disconnected:
            event = mapper.connectionState(for: connection.state).map(BikeOnboardingConnectionEvent.recovery)
        case .bluetoothUnavailable:
            event = .bluetooth(.unavailable)
        case .bluetoothPoweredOff:
            event = .bluetooth(.poweredOff)
        case .bluetoothUnauthorized:
            event = .bluetooth(.denied)
        default:
            event = mapper.connectionState(for: connection.state).map(BikeOnboardingConnectionEvent.progress)
        }
        if let event {
            eventContinuation.yield(event)
        }
    }
}
