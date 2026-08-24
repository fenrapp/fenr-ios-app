import BikeDomain
import Combine

@MainActor
public final class WatchOnboardingViewModel: ObservableObject {
    @Published private(set) var discoveredBikes: [DiscoveredBike] = []
    @Published private(set) var debugEvents: [BikeDebugEvent] = []
    @Published private(set) var detail = "Searching for nearby bikes"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isConnecting = false

    private let maximumDebugEvents = 12
    private let useCases: WatchOnboardingUseCases
    private let onCompleted: @MainActor (BikeProfile) -> Void
    private var connectionTask: Task<Void, Never>?
    private var debugTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
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
        debugTask?.cancel()
        discoveryTask?.cancel()
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
        debugTask?.cancel()
        debugTask = nil
        discoveryTask?.cancel()
        discoveryTask = nil
        let stopDiscovery = useCases.stopDiscovery
        Task { await stopDiscovery.execute() }
    }

    func scan() {
        discoveryTask?.cancel()
        discoveredBikes = []
        debugEvents = []
        errorMessage = nil
        detail = "Searching for nearby bikes"
        let observeDiscoveredBikes = useCases.observeDiscoveredBikes
        let startDiscovery = useCases.startDiscovery
        discoveryTask = Task { [weak self] in
            let stream = await observeDiscoveredBikes.execute()
            await startDiscovery.execute()
            for await bikes in stream {
                guard !Task.isCancelled else { return }
                self?.receive(bikes)
            }
        }
    }

    func select(_ bike: DiscoveredBike) {
        guard !isConnecting else { return }
        selectedVIN = bike.vin
        isConnecting = true
        detail = "Connecting to \(bike.vin)"
        discoveryTask?.cancel()
        let stopDiscovery = useCases.stopDiscovery
        let connectToBike = useCases.connectToBike
        Task {
            await stopDiscovery.execute()
            do {
                try await connectToBike.execute(vin: bike.vin)
            } catch {
                isConnecting = false
                errorMessage = "Unable to connect. Try again."
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
        discoveredBikes = bikes.sorted { $0.rssi > $1.rssi }
        guard discoveredBikes.count == 1, let bike = discoveredBikes.first else { return }
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
            isConnecting = false
            errorMessage = nil
            detail = "Receiving data"
            let profile = BikeProfile(vin: selectedVIN)
            let saveProfile = useCases.saveProfile
            Task { [onCompleted] in
                await saveProfile.execute(profile)
                onCompleted(profile)
            }
        case .failed(let message):
            isConnecting = false
            errorMessage = message
        case .bluetoothPoweredOff:
            isConnecting = false
            errorMessage = "Turn on Bluetooth to continue."
        case .bluetoothUnauthorized:
            isConnecting = false
            errorMessage = "Allow Bluetooth access to continue."
        default:
            detail = detail(for: connection.state)
        }
    }

    private func receive(_ event: BikeDebugEvent) {
        debugEvents.insert(event, at: 0)
        if debugEvents.count > maximumDebugEvents {
            debugEvents.removeLast(debugEvents.count - maximumDebugEvents)
        }
    }

    private func detail(for state: ConnectionState) -> String {
        switch state {
        case .connecting: "Connecting"
        case .discovering: "Discovering bike"
        case .authenticating: "Authenticating"
        case .authenticated, .subscribed: "Starting telemetry"
        case .reconnecting: "Reconnecting"
        default: detail
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
