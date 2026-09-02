import Foundation

public enum BikeOnboardingBluetoothAuthorization: Sendable {
    case notDetermined
    case allowed
    case denied
}

@MainActor
public final class BikeOnboardingViewModel: ObservableObject {
    @Published public private(set) var viewState: BikeOnboardingViewState

    private let discoveryCoordinator: BikeOnboardingDiscoveryCoordinator
    private let connectionCoordinator: BikeOnboardingConnectionCoordinator
    private let bluetoothAccessCoordinator: BikeOnboardingBluetoothAccessCoordinator
    private let completionCoordinator: BikeOnboardingCompletionCoordinator
    private let pairingCoordinator: BikeOnboardingPairingCoordinator
    private let eventCoordinator: BikeOnboardingEventCoordinator
    private let eventReducer: BikeOnboardingEventReducer
    private let onCompleted: @MainActor (String) -> Void
    private var eventTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var isObservingConnection = false

    public init(
        discoveryCoordinator: BikeOnboardingDiscoveryCoordinator,
        connectionCoordinator: BikeOnboardingConnectionCoordinator,
        bluetoothAccessCoordinator: BikeOnboardingBluetoothAccessCoordinator,
        completionCoordinator: BikeOnboardingCompletionCoordinator,
        pairingCoordinator: BikeOnboardingPairingCoordinator,
        eventCoordinator: BikeOnboardingEventCoordinator,
        eventReducer: BikeOnboardingEventReducer,
        initialVIN: String? = nil,
        onCompleted: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.discoveryCoordinator = discoveryCoordinator
        self.connectionCoordinator = connectionCoordinator
        self.bluetoothAccessCoordinator = bluetoothAccessCoordinator
        self.completionCoordinator = completionCoordinator
        self.pairingCoordinator = pairingCoordinator
        self.eventCoordinator = eventCoordinator
        self.eventReducer = eventReducer
        self.onCompleted = onCompleted
        viewState = BikeOnboardingViewState(vin: pairingCoordinator.normalizedVIN(initialVIN))
    }

    deinit {
        eventTask?.cancel()
        transitionTask?.cancel()
    }

    public func startObserving() {
        startEventObservation()
        guard !isObservingConnection else { return }
        isObservingConnection = true
        connectionCoordinator.startObserving()
    }

    public func stopObserving() {
        isObservingConnection = false
        connectionCoordinator.stopObserving()
        eventCoordinator.stopObserving()
        eventTask?.cancel()
        eventTask = nil
        bluetoothAccessCoordinator.cancelRequest()
        transitionTask?.cancel()
        transitionTask = nil
        let pendingDiscoveryStop = discoveryCoordinator.stop()
        guard viewState.step != .success else { return }
        connectionCoordinator.disconnect(after: pendingDiscoveryStop)
    }

    public func getStarted() {
        startEventObservation()
        routeBluetoothAuthorization(requestWhenUndetermined: false)
    }

    public func continueBluetooth() {
        startEventObservation()
        routeBluetoothAuthorization(requestWhenUndetermined: true)
    }

    public func retryDiscovery() {
        beginDiscovery()
    }

    public func selectDiscoveredBike(_ bike: BikeDiscoveryViewData) {
        guard let selection = pairingCoordinator.selection(vin: bike.vin, title: bike.modelTitle) else { return }
        viewState.vin = selection.vin
        viewState.selectedBikeTitle = selection.title
        viewState.pairingPIN = selection.pin
        viewState.didCopyPIN = false
        viewState.isDiscoveringBikes = false
        viewState.step = .pairing
        discoveryCoordinator.stop()
    }

    public func copyAndPair() {
        guard viewState.step == .pairing,
              pairingCoordinator.canConnect(vin: viewState.vin),
              pairingCoordinator.copy(pin: viewState.pairingPIN) else { return }
        viewState.didCopyPIN = true
        connectSelectedBike()
    }

    public func retryConnection() {
        guard pairingCoordinator.canConnect(vin: viewState.vin) else { return }
        connectSelectedBike()
    }

    public func cancelConnection() {
        viewState.connectionState = .inProgress(.finding)
        let disconnection = connectionCoordinator.disconnect()
        transitionTask?.cancel()
        transitionTask = Task { [weak self] in
            await disconnection.value
            guard !Task.isCancelled else { return }
            self?.beginDiscovery()
        }
    }

    public func setVoiceOverEnabled(_ isEnabled: Bool) {
        completionCoordinator.setRequiresExplicitContinuation(isEnabled)
    }

    public func continueFromSuccess() {
        guard viewState.step == .success else { return }
        completionCoordinator.continueFromSuccess()
    }

    public func back() {
        switch viewState.step {
        case .welcome, .success:
            break
        case .bluetooth:
            bluetoothAccessCoordinator.cancelRequest()
            viewState = BikeOnboardingViewState(step: .welcome, vin: viewState.vin)
        case .discovery:
            viewState.step = .welcome
            viewState.isDiscoveringBikes = false
            discoveryCoordinator.stop()
        case .pairing:
            beginDiscovery()
        case .connecting:
            cancelConnection()
        }
    }

    private func routeBluetoothAuthorization(requestWhenUndetermined: Bool) {
        switch bluetoothAccessCoordinator.authorization {
        case .allowed:
            beginDiscovery()
        case .denied:
            showBluetoothRecovery(.denied)
        case .notDetermined where requestWhenUndetermined:
            viewState.isRequestingBluetoothAccess = true
            viewState.bluetoothState = .requestingAccess
            bluetoothAccessCoordinator.requestAccess()
        case .notDetermined:
            viewState.step = .bluetooth
            viewState.bluetoothState = .preparation
        }
    }

    private func beginDiscovery() {
        startEventObservation()
        bluetoothAccessCoordinator.cancelRequest()
        viewState.step = .discovery
        viewState.bluetoothState = .preparation
        viewState.isRequestingBluetoothAccess = false
        viewState.connectionState = .inProgress(.finding)
        viewState.discoveredBikes = []
        viewState.discoveryState = .scanning
        viewState.isDiscoveringBikes = true
        discoveryCoordinator.start()
    }

    private func connectSelectedBike() {
        viewState.step = .connecting
        viewState.connectionState = .inProgress(.finding)
        connectionCoordinator.connect(vin: viewState.vin, after: discoveryCoordinator.stop())
    }

    private func completeOnboarding() {
        guard viewState.step != .success else { return }
        viewState.step = .success
        viewState.connectionState = .inProgress(.live)
        completionCoordinator.start(vin: viewState.vin)
    }

    private func showBluetoothRecovery(_ state: BikeOnboardingBluetoothState) {
        let wasConnecting = viewState.step == .connecting
        bluetoothAccessCoordinator.cancelRequest()
        let pendingDiscoveryStop = discoveryCoordinator.stop()
        if wasConnecting {
            connectionCoordinator.disconnect(after: pendingDiscoveryStop)
        }
        viewState.step = .bluetooth
        viewState.bluetoothState = state
        viewState.isRequestingBluetoothAccess = false
        viewState.isDiscoveringBikes = false
        viewState.connectionState = .inProgress(.finding)
    }

    private func startEventObservation() {
        guard eventTask == nil else { return }
        eventCoordinator.startObserving()
        let events = eventCoordinator.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else { return }
                self?.receive(event)
            }
        }
    }

    private func receive(_ event: BikeOnboardingEvent) {
        let effect = eventReducer.reduce(event, state: &viewState)
        switch effect {
        case .none:
            break
        case .beginDiscovery:
            beginDiscovery()
        case .selectBike(let bike):
            selectDiscoveredBike(bike)
        case .completeOnboarding:
            completeOnboarding()
        case .showBluetoothRecovery(let state):
            showBluetoothRecovery(state)
        case .stopFailedDiscovery:
            discoveryCoordinator.stop()
            viewState.discoveryState = .failed
            viewState.isDiscoveringBikes = false
        case .finish(let vin):
            onCompleted(vin)
        }
    }

#if DEBUG
    func setPreviewState(_ state: BikeOnboardingViewState) {
        viewState = state
    }
#endif
}
