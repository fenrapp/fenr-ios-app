import BikeDomain
import Foundation
import RuntimeConfiguration
import StarkProtocol

@MainActor
public final class BikeOnboardingViewModel: ObservableObject {
    @Published public private(set) var viewState: BikeOnboardingViewState

    private let useCases: BikeOnboardingUseCases
    private var connectionTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var bluetoothAccessTask: Task<Void, Never>?
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
        bluetoothAccessTask?.cancel()
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
        bluetoothAccessTask?.cancel()
        bluetoothAccessTask = nil
        stopDiscovery()
    }

    public func next() {
        if viewState.step == .preparation {
            requestBluetoothAccess()
            return
        }
        guard let next = BikeOnboardingStep(rawValue: viewState.step.rawValue + 1) else { return }
        guard viewState.step != .identify || StarkPairingIdentity.isValidVIN(viewState.vin) else {
            viewState.errorMessage = "Enter a valid 17-character VIN."
            viewState.showsBluetoothSettingsButton = false
            return
        }
        viewState.step = next
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        if next == .identify { startDiscovery() }
        if next == .connect { connect() }
    }

    public func back() {
        guard let previous = BikeOnboardingStep(rawValue: viewState.step.rawValue - 1) else { return }
        viewState.step = previous
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        if previous == .identify { startDiscovery() }
    }

    public func vinChanged(_ value: String) {
        viewState.vin = StarkPairingIdentity.normalizedVIN(value)
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
    }

    public func startDiscovery() {
        guard !viewState.isDiscoveringBikes else { return }
        viewState.isDiscoveringBikes = true
        viewState.discoveredBikes = []
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
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

    private func requestBluetoothAccess() {
        guard !viewState.isRequestingBluetoothAccess else { return }
        guard !viewState.showsBluetoothSettingsButton else {
            viewState.errorMessage = "Allow Bluetooth access in Settings > FENR, then return to continue."
            return
        }
        viewState.isRequestingBluetoothAccess = true
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        viewState.connectionDetail = "Checking Bluetooth access"
        let start = useCases.start
        bluetoothAccessTask = Task { [weak self] in
            await start.execute()
            try? await Task.sleep(for: FENRRuntimeConstants.Onboarding.bluetoothPermissionResponseTimeout)
            await MainActor.run {
                guard let self, self.viewState.isRequestingBluetoothAccess else { return }
                self.viewState.isRequestingBluetoothAccess = false
                self.viewState.showsBluetoothSettingsButton = false
                self.viewState.errorMessage = """
                Bluetooth access is still pending. Try again and respond to the iOS prompt.
                """
            }
        }
    }

    private func advanceAfterBluetoothAccess() {
        viewState.isRequestingBluetoothAccess = false
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        guard viewState.step == .preparation else { return }
        viewState.step = .identify
        startDiscovery()
    }

    private func connect() {
        guard StarkPairingIdentity.isValidVIN(viewState.vin) else { return }
        viewState.isConnecting = true
        stopDiscovery()
        viewState.connectionDetail = "Looking for \(viewState.vin)"
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        let vin = viewState.vin
        let connect = useCases.connect
        Task {
            do {
                try await connect.execute(vin: vin)
            } catch {
                await MainActor.run {
                    self.viewState.isConnecting = false
                    self.viewState.errorMessage = "Unable to start the connection."
                    self.viewState.showsBluetoothSettingsButton = false
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
        case .idle:
            guard viewState.isRequestingBluetoothAccess else {
                viewState.connectionDetail = connectionDetail(connection.state)
                return
            }
            bluetoothAccessTask?.cancel()
            bluetoothAccessTask = nil
            advanceAfterBluetoothAccess()
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
            viewState.showsBluetoothSettingsButton = false
        case .bluetoothPoweredOff:
            bluetoothAccessTask?.cancel()
            bluetoothAccessTask = nil
            viewState.isRequestingBluetoothAccess = false
            viewState.isConnecting = false
            viewState.errorMessage = "Turn on Bluetooth and try again."
            viewState.showsBluetoothSettingsButton = false
        case .bluetoothUnauthorized:
            bluetoothAccessTask?.cancel()
            bluetoothAccessTask = nil
            viewState.isRequestingBluetoothAccess = false
            viewState.isConnecting = false
            viewState.errorMessage = "Allow Bluetooth access in Settings > FENR, then return to continue."
            viewState.showsBluetoothSettingsButton = true
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
