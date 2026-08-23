import BikeDomain
import Foundation
import StarkProtocol

@MainActor
public final class BikeOnboardingViewModel: ObservableObject {
    @Published public private(set) var viewState: BikeOnboardingViewState

    private let useCases: BikeOnboardingUseCases
    private var connectionTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var isObserving = false
    private var didComplete = false
    private let onCompleted: @MainActor (String) -> Void

    public init(
        useCases: BikeOnboardingUseCases,
        initialVIN: String? = nil,
        onCompleted: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.useCases = useCases
        self.onCompleted = onCompleted
        viewState = .init(vin: initialVIN.map(StarkPairingIdentity.normalizedVIN) ?? "")
    }

    deinit {
        connectionTask?.cancel()
        discoveryTask?.cancel()
    }

    public func startObserving() {
        guard !isObserving else { return }
        isObserving = true
        let observeConnection = useCases.observeConnection
        connectionTask = Task { [weak self] in
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.receive(connection)
            }
        }
    }

    public func stopObserving() {
        isObserving = false
        connectionTask?.cancel()
        connectionTask = nil
        stopDiscovery()
    }

    public func next() {
        guard let next = BikeOnboardingStep(rawValue: viewState.step.rawValue + 1) else { return }
        guard viewState.step != .identify || StarkPairingIdentity.isValidVIN(viewState.vin) else {
            viewState.errorMessage = "Enter a valid 17-character VIN."
            return
        }
        viewState.step = next
        viewState.errorMessage = nil
        if next == .identify { startDiscovery() }
        if next == .connect { connect() }
    }

    public func back() {
        guard let previous = BikeOnboardingStep(rawValue: viewState.step.rawValue - 1) else { return }
        viewState.step = previous
        viewState.errorMessage = nil
        if previous == .identify { startDiscovery() }
    }

    public func vinChanged(_ value: String) {
        viewState.vin = StarkPairingIdentity.normalizedVIN(value)
        viewState.errorMessage = nil
    }

    public func startDiscovery() {
        guard !viewState.isDiscoveringBikes else { return }
        viewState.isDiscoveringBikes = true
        viewState.discoveredBikes = []
        viewState.errorMessage = nil
        let observeDiscoveredBikes = useCases.observeDiscoveredBikes
        let startDiscovery = useCases.startDiscovery
        discoveryTask = Task { [weak self] in
            let stream = await observeDiscoveredBikes.execute()
            await startDiscovery.execute()
            for await bikes in stream {
                guard !Task.isCancelled else { return }
                self?.receive(discoveredBikes: bikes)
            }
        }
    }

    public func selectDiscoveredBike(_ bike: DiscoveredBike) {
        vinChanged(bike.vin)
        stopDiscovery()
    }

    public func retry() { connect() }

#if DEBUG
    func setPreviewState(_ viewState: BikeOnboardingViewState) {
        self.viewState = viewState
    }
#endif

    private func connect() {
        guard StarkPairingIdentity.isValidVIN(viewState.vin) else { return }
        viewState.isConnecting = true
        stopDiscovery()
        viewState.connectionDetail = "Looking for \(viewState.vin)"
        viewState.errorMessage = nil
        let vin = viewState.vin
        let connect = useCases.connect
        Task {
            do {
                try await connect.execute(vin: vin)
            } catch {
                await MainActor.run {
                    self.viewState.isConnecting = false
                    self.viewState.errorMessage = "Unable to start the connection."
                }
            }
        }
    }

    private func receive(discoveredBikes: [DiscoveredBike]) {
        for bike in discoveredBikes where !viewState.discoveredBikes.contains(where: { $0.vin == bike.vin }) {
            viewState.discoveredBikes.append(bike)
        }
        viewState.discoveredBikes.sort { $0.rssi > $1.rssi }
        guard viewState.discoveredBikes.count == 1, let bike = viewState.discoveredBikes.first else { return }
        selectDiscoveredBike(bike)
    }

    private func stopDiscovery() {
        viewState.isDiscoveringBikes = false
        discoveryTask?.cancel()
        discoveryTask = nil
        let stopDiscovery = useCases.stopDiscovery
        Task { await stopDiscovery.execute() }
    }

    private func receive(_ connection: BikeConnection) {
        switch connection.state {
        case .receivingTelemetry(let peripheralName):
            guard peripheralName == nil || peripheralName == viewState.vin else { return }
            guard !didComplete else { return }
            didComplete = true
            viewState.isConnecting = false
            let profile = BikeProfile(vin: viewState.vin)
            let saveProfile = useCases.saveProfile
            Task { [onCompleted] in
                await saveProfile.execute(profile)
                onCompleted(profile.vin)
            }
        case .failed(let message):
            viewState.isConnecting = false
            viewState.errorMessage = message
        case .bluetoothPoweredOff:
            viewState.isConnecting = false
            viewState.errorMessage = "Turn on Bluetooth and try again."
        case .bluetoothUnauthorized:
            viewState.isConnecting = false
            viewState.errorMessage = "Allow Bluetooth access in Settings."
        default:
            viewState.connectionDetail = connectionDetail(connection.state)
        }
    }

    private func connectionDetail(_ state: ConnectionState) -> String {
        switch state {
        case .scanning: "Scanning for your bike"
        case .connecting: "Connecting"
        case .discovering: "Discovering services"
        case .authenticating: "Authenticating"
        case .authenticated, .subscribed: "Subscribing to telemetry"
        case .reconnecting(_, let attempt, let maximumAttempts): "Reconnecting (\(attempt)/\(maximumAttempts))"
        default: "Ready to connect"
        }
    }
}
