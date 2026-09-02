import RuntimeConfiguration

enum BikeOnboardingBluetoothAccessEvent: Sendable {
    case allowed
    case denied
    case unanswered
}

@MainActor
public final class BikeOnboardingBluetoothAccessCoordinator {
    let events: AsyncStream<BikeOnboardingBluetoothAccessEvent>

    private let repositoryStarter: BikeOnboardingRepositoryStarter
    private let timing: BikeOnboardingTiming
    private let authorizationProvider: @MainActor @Sendable () -> BikeOnboardingBluetoothAuthorization
    private let eventContinuation: AsyncStream<BikeOnboardingBluetoothAccessEvent>.Continuation
    private var requestTask: Task<Void, Never>?

    public init(
        repositoryStarter: BikeOnboardingRepositoryStarter,
        timing: BikeOnboardingTiming,
        authorizationProvider: @escaping @MainActor @Sendable () -> BikeOnboardingBluetoothAuthorization
    ) {
        self.repositoryStarter = repositoryStarter
        self.timing = timing
        self.authorizationProvider = authorizationProvider
        let eventChannel = AsyncStream<BikeOnboardingBluetoothAccessEvent>.makeStream()
        events = eventChannel.stream
        eventContinuation = eventChannel.continuation
    }

    deinit {
        requestTask?.cancel()
        eventContinuation.finish()
    }

    var authorization: BikeOnboardingBluetoothAuthorization {
        authorizationProvider()
    }

    func requestAccess() {
        requestTask?.cancel()
        let pendingRepositoryStart = repositoryStarter.start()
        let timing = timing
        requestTask = Task { [weak self] in
            await pendingRepositoryStart.value
            do {
                try await timing.sleep(FENRRuntimeConstants.Onboarding.bluetoothPermissionResponseTimeout)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            switch self.authorization {
            case .allowed:
                self.eventContinuation.yield(.allowed)
            case .denied:
                self.eventContinuation.yield(.denied)
            case .notDetermined:
                self.eventContinuation.yield(.unanswered)
            }
        }
    }

    func cancelRequest() {
        requestTask?.cancel()
        requestTask = nil
    }
}
