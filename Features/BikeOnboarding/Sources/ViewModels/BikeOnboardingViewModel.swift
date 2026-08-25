import BikeDomain
import CoreBluetooth
import Foundation
import RuntimeConfiguration
import StarkProtocol

public enum BikeOnboardingBluetoothAuthorization: Sendable {
    case notDetermined
    case allowed
    case denied
}

@MainActor
public final class BikeOnboardingViewModel: ObservableObject {
    @Published public private(set) var viewState: BikeOnboardingViewState

    private let useCases: BikeOnboardingUseCases
    private var connectionTask: Task<Void, Never>?
    private var connectionAttemptTask: Task<Void, Never>?
    private var discoveryTask: Task<Void, Never>?
    private var discoveryStopTask: Task<Void, Never>?
    private var bluetoothAccessTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var discoveredBikeSignals: [String: Int] = [:]
    private var isObserving = false
    private var isBluetoothAccessKnownDenied = false
    private var didComplete = false
    private let bluetoothAuthorization: @MainActor @Sendable () -> BikeOnboardingBluetoothAuthorization
    private let onCompleted: @MainActor (String) -> Void

    public init(
        useCases: BikeOnboardingUseCases,
        initialVIN: String? = nil,
        bluetoothAuthorization: @escaping @MainActor @Sendable () -> BikeOnboardingBluetoothAuthorization = {
            switch CBManager.authorization {
            case .allowedAlways: .allowed
            case .denied, .restricted: .denied
            case .notDetermined: .notDetermined
            @unknown default: .notDetermined
            }
        },
        onCompleted: @escaping @MainActor (String) -> Void = { _ in }
    ) {
        self.useCases = useCases
        self.bluetoothAuthorization = bluetoothAuthorization
        self.onCompleted = onCompleted
        let normalizedVIN = initialVIN.map(StarkPairingIdentity.normalizedVIN) ?? ""
        viewState = .init(
            vin: normalizedVIN,
            canContinue: Self.canContinue(step: .welcome, vin: normalizedVIN)
        )
    }

    deinit {
        connectionTask?.cancel()
        connectionAttemptTask?.cancel()
        discoveryTask?.cancel()
        discoveryStopTask?.cancel()
        bluetoothAccessTask?.cancel()
        completionTask?.cancel()
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
        connectionAttemptTask?.cancel()
        connectionAttemptTask = nil
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
        viewState.canContinue = Self.canContinue(step: next, vin: viewState.vin)
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        if next == .preparation { restoreKnownBluetoothAccessDenialIfNeeded() }
        if next == .identify { startDiscovery() }
        if next == .connect { connect() }
    }

    public func back() {
        guard let previous = BikeOnboardingStep(rawValue: viewState.step.rawValue - 1) else { return }
        viewState.step = previous
        viewState.canContinue = Self.canContinue(step: previous, vin: viewState.vin)
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        if previous == .preparation { restoreKnownBluetoothAccessDenialIfNeeded() }
        if previous == .identify { startDiscovery() }
    }

    public func vinChanged(_ value: String) {
        viewState.vin = StarkPairingIdentity.normalizedVIN(value)
        refreshDiscoveredBikeViewData()
        viewState.canContinue = Self.canContinue(step: viewState.step, vin: viewState.vin)
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
    }

    public func scannedVIN(_ value: String) -> Bool {
        let normalizedVIN = StarkPairingIdentity.normalizedVIN(value)
        guard StarkPairingIdentity.isValidVIN(normalizedVIN) else { return false }
        vinChanged(normalizedVIN)
        return true
    }

    public func startDiscovery() {
        guard !viewState.isDiscoveringBikes else { return }
        viewState.isDiscoveringBikes = true
        discoveredBikeSignals = [:]
        viewState.discoveredBikes = []
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
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
                self?.receive(discoveredBikes: bikes)
            }
        }
    }

    public func selectDiscoveredBike(_ bike: BikeDiscoveryViewData) {
        vinChanged(bike.vin)
        stopDiscovery()
    }

    public func retry() { connect() }

#if DEBUG
    func setPreviewState(_ viewState: BikeOnboardingViewState) {
        self.viewState = viewState
    }
#endif
}

private extension BikeOnboardingViewModel {
    private func requestBluetoothAccess() {
        guard !viewState.isRequestingBluetoothAccess else { return }
        refreshKnownBluetoothAccessDenial()
        guard !isBluetoothAccessKnownDenied else {
            restoreKnownBluetoothAccessDenialIfNeeded()
            return
        }
        viewState.isRequestingBluetoothAccess = true
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        viewState.connectionDetail = "Checking Bluetooth access"
        let start = useCases.start
        bluetoothAccessTask = Task { [weak self] in
            await start.execute()
            guard !Task.isCancelled else { return }
            do {
                try await Task.sleep(for: FENRRuntimeConstants.Onboarding.bluetoothPermissionResponseTimeout)
            } catch {
                return
            }
            guard !Task.isCancelled, let self, self.viewState.isRequestingBluetoothAccess else { return }
            if self.bluetoothAuthorization() == .allowed {
                self.advanceAfterBluetoothAccess()
                return
            }
            self.viewState.isRequestingBluetoothAccess = false
            self.viewState.showsBluetoothSettingsButton = false
            self.viewState.errorMessage = """
            Bluetooth access is still pending. Try again and respond to the iOS prompt.
            """
        }
    }

    private func advanceAfterBluetoothAccess() {
        isBluetoothAccessKnownDenied = false
        viewState.isRequestingBluetoothAccess = false
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        guard viewState.step == .preparation else { return }
        viewState.step = .identify
        viewState.canContinue = Self.canContinue(step: .identify, vin: viewState.vin)
        startDiscovery()
    }

    private func connect() {
        guard StarkPairingIdentity.isValidVIN(viewState.vin) else { return }
        viewState.isConnecting = true
        viewState.connectionPhase = .scanning
        viewState.connectionDetail = "Looking for \(viewState.vin)"
        viewState.errorMessage = nil
        viewState.showsBluetoothSettingsButton = false
        let vin = viewState.vin
        let connect = useCases.connect
        let pendingStop = stopDiscovery()
        connectionAttemptTask?.cancel()
        connectionAttemptTask = Task { [weak self] in
            await pendingStop.value
            guard !Task.isCancelled else { return }
            do {
                try await connect.execute(vin: vin)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.viewState.isConnecting = false
                self.viewState.errorMessage = "Unable to start the connection."
                self.viewState.showsBluetoothSettingsButton = false
            }
        }
    }

    private func receive(discoveredBikes: [DiscoveredBike]) {
        for bike in discoveredBikes {
            discoveredBikeSignals[bike.vin] = bike.rssi
        }
        refreshDiscoveredBikeViewData()
        guard viewState.discoveredBikes.count == 1, let bike = viewState.discoveredBikes.first else { return }
        selectDiscoveredBike(bike)
    }

    private func refreshDiscoveredBikeViewData() {
        viewState.discoveredBikes = discoveredBikeSignals
            .sorted { $0.value > $1.value }
            .map { vin, rssi in
                .init(
                    vin: vin,
                    signalText: signalText(for: rssi),
                    isSelected: vin == viewState.vin
                )
            }
    }

    private func signalText(for rssi: Int) -> String {
        switch rssi {
        case (-55)...: "Strong signal"
        case -70 ..< -55: "Good signal"
        default: "Weak signal"
        }
    }

    @discardableResult
    private func stopDiscovery() -> Task<Void, Never> {
        viewState.isDiscoveringBikes = false
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

    private func receive(_ connection: BikeConnection) {
        switch connection.state {
        case .idle:
            isBluetoothAccessKnownDenied = false
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
            viewState.connectionPhase = .subscribing
            let profile = BikeProfile(vin: viewState.vin)
            let saveProfile = useCases.saveProfile
            completionTask?.cancel()
            completionTask = Task { [weak self, onCompleted] in
                await saveProfile.execute(profile)
                guard !Task.isCancelled, self?.didComplete == true else { return }
                onCompleted(profile.vin)
            }
        case .failed(let message):
            viewState.isConnecting = false
            viewState.connectionPhase = nil
            viewState.errorMessage = message
            viewState.showsBluetoothSettingsButton = false
        case .bluetoothPoweredOff:
            bluetoothAccessTask?.cancel()
            bluetoothAccessTask = nil
            viewState.isRequestingBluetoothAccess = false
            viewState.isConnecting = false
            viewState.connectionPhase = nil
            viewState.errorMessage = "Turn on Bluetooth and try again."
            viewState.showsBluetoothSettingsButton = false
        case .bluetoothUnauthorized:
            bluetoothAccessTask?.cancel()
            bluetoothAccessTask = nil
            isBluetoothAccessKnownDenied = true
            viewState.isRequestingBluetoothAccess = false
            viewState.isConnecting = false
            viewState.connectionPhase = nil
            viewState.errorMessage = "Allow Bluetooth access in Settings > FENR, then return to continue."
            viewState.showsBluetoothSettingsButton = true
        default:
            isBluetoothAccessKnownDenied = false
            viewState.connectionPhase = connectionPhase(connection.state)
            viewState.connectionDetail = connectionDetail(connection.state)
        }
    }

    private func restoreKnownBluetoothAccessDenialIfNeeded() {
        refreshKnownBluetoothAccessDenial()
        guard isBluetoothAccessKnownDenied, viewState.step == .preparation else { return }
        bluetoothAccessTask?.cancel()
        bluetoothAccessTask = nil
        viewState.isRequestingBluetoothAccess = false
        viewState.isConnecting = false
        viewState.connectionPhase = nil
        viewState.errorMessage = "Allow Bluetooth access in Settings > FENR, then return to continue."
        viewState.showsBluetoothSettingsButton = true
    }

    private func refreshKnownBluetoothAccessDenial() {
        switch bluetoothAuthorization() {
        case .denied:
            isBluetoothAccessKnownDenied = true
        case .allowed:
            isBluetoothAccessKnownDenied = false
        case .notDetermined:
            break
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

    private func connectionPhase(_ state: ConnectionState) -> BikeOnboardingConnectionPhase? {
        switch state {
        case .scanning: .scanning
        case .connecting: .connecting
        case .discovering: .discovering
        case .authenticating, .authenticated: .authenticating
        case .subscribed, .receivingTelemetry: .subscribing
        default: nil
        }
    }

    private static func canContinue(step: BikeOnboardingStep, vin: String) -> Bool {
        step != .identify || StarkPairingIdentity.isValidVIN(vin)
    }
}
