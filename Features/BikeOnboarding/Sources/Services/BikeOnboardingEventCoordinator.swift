enum BikeOnboardingEvent: Sendable {
    case discovery(BikeOnboardingDiscoveryEvent)
    case connection(BikeOnboardingConnectionEvent)
    case bluetooth(BikeOnboardingBluetoothAccessEvent)
    case completion(BikeOnboardingCompletionEvent)
}

@MainActor
public final class BikeOnboardingEventCoordinator {
    let events: AsyncStream<BikeOnboardingEvent>

    private let discoveryEvents: AsyncStream<BikeOnboardingDiscoveryEvent>
    private let connectionEvents: AsyncStream<BikeOnboardingConnectionEvent>
    private let bluetoothEvents: AsyncStream<BikeOnboardingBluetoothAccessEvent>
    private let completionEvents: AsyncStream<BikeOnboardingCompletionEvent>
    private let eventContinuation: AsyncStream<BikeOnboardingEvent>.Continuation
    private var observationTasks: [Task<Void, Never>] = []

    public init(
        discoveryCoordinator: BikeOnboardingDiscoveryCoordinator,
        connectionCoordinator: BikeOnboardingConnectionCoordinator,
        bluetoothAccessCoordinator: BikeOnboardingBluetoothAccessCoordinator,
        completionCoordinator: BikeOnboardingCompletionCoordinator
    ) {
        discoveryEvents = discoveryCoordinator.events
        connectionEvents = connectionCoordinator.events
        bluetoothEvents = bluetoothAccessCoordinator.events
        completionEvents = completionCoordinator.events
        let eventChannel = AsyncStream<BikeOnboardingEvent>.makeStream()
        events = eventChannel.stream
        eventContinuation = eventChannel.continuation
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        eventContinuation.finish()
    }

    func startObserving() {
        guard observationTasks.isEmpty else { return }
        observationTasks = [
            forward(discoveryEvents, as: BikeOnboardingEvent.discovery),
            forward(connectionEvents, as: BikeOnboardingEvent.connection),
            forward(bluetoothEvents, as: BikeOnboardingEvent.bluetooth),
            forward(completionEvents, as: BikeOnboardingEvent.completion)
        ]
    }

    func stopObserving() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
    }

    private func forward<Event: Sendable>(
        _ source: AsyncStream<Event>,
        as transform: @escaping @Sendable (Event) -> BikeOnboardingEvent
    ) -> Task<Void, Never> {
        let eventContinuation = eventContinuation
        return Task {
            for await event in source {
                guard !Task.isCancelled else { return }
                eventContinuation.yield(transform(event))
            }
        }
    }
}
