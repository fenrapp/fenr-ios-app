import BikeDomain
import Combine
import Foundation

@MainActor
public final class WatchOnboardingViewModel: ObservableObject {
    @Published private(set) var viewState = WatchOnboardingViewState()

    private let maximumDebugEvents = 12
    private let useCases: WatchOnboardingUseCases
    private let onCompleted: @MainActor (BikeProfile) -> Void
    private var connectionTask: Task<Void, Never>?
    private var connectionAttemptTask: Task<Void, Never>?
    private var debugTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var discoveryStopTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var selectedVIN: String?
    private var didComplete = false

    public init(
        useCases: WatchOnboardingUseCases,
        onCompleted: @escaping @MainActor (BikeProfile) -> Void
    ) {
        self.useCases = useCases
        self.onCompleted = onCompleted
    }

    deinit {
        connectionTask?.cancel()
        connectionAttemptTask?.cancel()
        debugTask?.cancel()
        discoveryTask?.cancel()
        discoveryStopTask?.cancel()
        completionTask?.cancel()
    }

    func start() {
        guard connectionTask == nil else { return }
        observeConnection()
        observeDebugEvents()
        scan()
    }

    func stop() {
        connectionTask?.cancel()
        connectionTask = nil
        connectionAttemptTask?.cancel()
        connectionAttemptTask = nil
        debugTask?.cancel()
        debugTask = nil
        stopDiscovery()
    }

    func scan() {
        discoveryTask?.cancel()
        viewState.discoveredBikes = []
        viewState.debugEvents = []
        viewState.errorMessage = nil
        viewState.detail = String(localized: .watchOnboardingSearching)
        let observeDiscoveredBikes = useCases.observeDiscoveredBikes
        let startDiscovery = useCases.startDiscovery
        let pendingStop = discoveryStopTask
        discoveryTask = Task { [weak self] in
            await pendingStop?.value
            guard !Task.isCancelled else { return }
            let stream = await observeDiscoveredBikes.execute()
            guard !Task.isCancelled else { return }
            await startDiscovery.execute()
            guard !Task.isCancelled else { return }
            for await bikes in stream {
                guard !Task.isCancelled else { return }
                self?.receive(bikes)
            }
        }
    }

    func select(_ bike: WatchDiscoveredBikeViewData) {
        guard !viewState.isConnecting else { return }
        selectedVIN = bike.vin
        viewState.isConnecting = true
        viewState.detail = String(localized: .watchOnboardingConnectingToBike(vin: bike.vin))
        let pendingStop = stopDiscovery()
        let connectToBike = useCases.connectToBike
        connectionAttemptTask?.cancel()
        connectionAttemptTask = Task { [weak self] in
            await pendingStop.value
            guard !Task.isCancelled else { return }
            do {
                try await connectToBike.execute(vin: bike.vin)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.viewState.isConnecting = false
                self.viewState.errorMessage = String(localized: .watchOnboardingUnableToConnect)
            }
        }
    }

    private func observeConnection() {
        let observeConnection = useCases.observeConnection
        connectionTask = Task { [weak self] in
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.receive(connection)
            }
        }
    }

    private func observeDebugEvents() {
        let observeDebugEvents = useCases.observeDebugEvents
        debugTask = Task { [weak self] in
            let stream = await observeDebugEvents.execute()
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.receive(event)
            }
        }
    }

    private func receive(_ bikes: [DiscoveredBike]) {
        viewState.discoveredBikes = bikes
            .sorted { $0.rssi > $1.rssi }
            .map {
                .init(
                    vin: $0.vin,
                    signalText: String(localized: .watchOnboardingSignal(rssi: $0.rssi))
                )
            }
        guard viewState.discoveredBikes.count == 1, let bike = viewState.discoveredBikes.first else { return }
        select(bike)
    }

    private func receive(_ connection: BikeConnection) {
        if let vin = vin(from: connection.state), !vin.isEmpty {
            selectedVIN = vin
        }
        switch connection.state {
        case .receivingTelemetry:
            guard let selectedVIN, !didComplete else { return }
            didComplete = true
            viewState.isConnecting = false
            viewState.errorMessage = nil
            viewState.detail = String(localized: .watchOnboardingReceivingData)
            let profile = BikeProfile(vin: selectedVIN)
            let saveProfile = useCases.saveProfile
            completionTask?.cancel()
            completionTask = Task { [weak self, onCompleted] in
                await saveProfile.execute(profile)
                guard !Task.isCancelled, self?.didComplete == true else { return }
                onCompleted(profile)
            }
        case .failed:
            viewState.isConnecting = false
            viewState.errorMessage = String(localized: .watchOnboardingUnableToConnect)
        case .pairingResetRequired:
            viewState.isConnecting = false
            viewState.errorMessage = String(localized: .watchOnboardingPairAgain)
        case .bluetoothPoweredOff:
            viewState.isConnecting = false
            viewState.errorMessage = String(localized: .watchOnboardingTurnOnBluetooth)
        case .bluetoothUnauthorized:
            viewState.isConnecting = false
            viewState.errorMessage = String(localized: .watchOnboardingAllowBluetooth)
        default:
            viewState.detail = detail(for: connection.state)
        }
    }

    private func receive(_ event: BikeDebugEvent) {
        viewState.debugEvents.insert(.init(id: event.id, title: event.title, detail: event.detail), at: 0)
        if viewState.debugEvents.count > maximumDebugEvents {
            viewState.debugEvents.removeLast(viewState.debugEvents.count - maximumDebugEvents)
        }
    }

    @discardableResult
    private func stopDiscovery() -> Task<Void, Never> {
        discoveryTask?.cancel()
        discoveryTask = nil
        let previousStop = discoveryStopTask
        let stopDiscovery = useCases.stopDiscovery
        let task = Task {
            await previousStop?.value
            guard !Task.isCancelled else { return }
            await stopDiscovery.execute()
        }
        discoveryStopTask = task
        return task
    }

    private func detail(for state: ConnectionState) -> String {
        switch state {
        case .connecting: String(localized: .watchOnboardingConnecting)
        case .discovering: String(localized: .watchOnboardingDiscoveringBike)
        case .authenticating: String(localized: .watchOnboardingAuthenticating)
        case .authenticated, .subscribed: String(localized: .watchOnboardingStartingTelemetry)
        case .reconnecting: String(localized: .watchOnboardingReconnecting)
        case .pairingResetRequired: String(localized: .watchOnboardingPairAgain)
        default: viewState.detail
        }
    }

    private func vin(from state: ConnectionState) -> String? {
        switch state {
        case .scanning(let vin), .connecting(let vin, _), .reconnecting(let vin, _, _):
            vin
        default:
            nil
        }
    }
}
