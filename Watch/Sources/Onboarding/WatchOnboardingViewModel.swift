import BikeDomain
import Combine

@MainActor
final class WatchOnboardingViewModel: ObservableObject {
    @Published private(set) var discoveredBikes: [DiscoveredBike] = []
    @Published private(set) var detail = "Searching for nearby bikes"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isConnecting = false

    private let repository: any BikeRepository
    private let discoveryRepository: any BikeDiscoveryRepository
    private let profileRepository: any BikeProfileRepository
    private let onCompleted: @MainActor (BikeProfile) -> Void
    private var connectionTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var selectedVIN: String?
    private var didComplete = false

    init(
        repository: any BikeRepository,
        discoveryRepository: any BikeDiscoveryRepository,
        profileRepository: any BikeProfileRepository,
        onCompleted: @escaping @MainActor (BikeProfile) -> Void
    ) {
        self.repository = repository
        self.discoveryRepository = discoveryRepository
        self.profileRepository = profileRepository
        self.onCompleted = onCompleted
    }

    deinit {
        connectionTask?.cancel()
        discoveryTask?.cancel()
    }

    func start() {
        guard connectionTask == nil else { return }
        observeConnection()
        scan()
    }

    func stop() {
        connectionTask?.cancel()
        connectionTask = nil
        discoveryTask?.cancel()
        discoveryTask = nil
        Task { await discoveryRepository.stopBikeDiscovery() }
    }

    func scan() {
        discoveryTask?.cancel()
        discoveredBikes = []
        errorMessage = nil
        detail = "Searching for nearby bikes"
        let discoveryRepository = discoveryRepository
        discoveryTask = Task { [weak self] in
            let stream = await discoveryRepository.observeDiscoveredBikes()
            await discoveryRepository.startBikeDiscovery()
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
        Task {
            await discoveryRepository.stopBikeDiscovery()
            do {
                try await repository.connect(vin: bike.vin)
            } catch {
                isConnecting = false
                errorMessage = "Unable to connect. Try again."
            }
        }
    }

    private func observeConnection() {
        let repository = repository
        connectionTask = Task { [weak self] in
            let stream = await repository.observeConnection()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.receive(connection)
            }
        }
    }

    private func receive(_ bikes: [DiscoveredBike]) {
        discoveredBikes = bikes.sorted { $0.rssi > $1.rssi }
        guard discoveredBikes.count == 1, let bike = discoveredBikes.first else { return }
        select(bike)
    }

    private func receive(_ connection: BikeConnection) {
        switch connection.state {
        case .receivingTelemetry(let name):
            guard let selectedVIN, name == nil || name == selectedVIN, !didComplete else { return }
            didComplete = true
            let profile = BikeProfile(vin: selectedVIN)
            Task { [profileRepository, onCompleted] in
                await profileRepository.saveProfile(profile)
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
}
