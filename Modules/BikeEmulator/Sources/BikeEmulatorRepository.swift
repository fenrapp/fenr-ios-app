import BikeDomain
import Foundation

public actor BikeEmulatorRepository: BikeRepository, BikeBatteryHealthRepository, BikeDiscoveryRepository {
    private let telemetryHub = BikeEmulatorEventHub<BikeTelemetry>(replaysLatestValue: true)
    private let connectionHub = BikeEmulatorEventHub<BikeConnection>(replaysLatestValue: true)
    private let debugEventHub = BikeEmulatorEventHub<BikeDebugEvent>(replaysLatestValue: true)
    private let batteryHealthHub = BikeEmulatorEventHub<BikeBatteryHealth>(replaysLatestValue: true)
    private let captureHub = BikeEmulatorCaptureHub()
    private let discoveredBikesHub = BikeEmulatorEventHub<[DiscoveredBike]>(replaysLatestValue: true)

    private var scenario: BikeEmulatorScenario
    private var tick = 0
    private var isStarted = false
    private var isBatteryHealthMonitoring = false
    private var updateTask: Task<Void, Never>?

    public init(scenario: BikeEmulatorScenario = .charging) {
        self.scenario = scenario
    }

    deinit {
        updateTask?.cancel()
    }

    public func start() async {
        guard !isStarted else { return }
        isStarted = true
        await publishCurrentState()
        scheduleUpdates()
    }

    public func stop() async {
        isStarted = false
        updateTask?.cancel()
        updateTask = nil
    }

    public func connect(vin: String) async throws {
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Connected to \(scenario.displayName)")
    }

    public func startBikeDiscovery() async {
        await discoveredBikesHub.send([.init(vin: BikeEmulatorIdentity.vin, rssi: -45)])
    }

    public func stopBikeDiscovery() async {}

    public func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> {
        await discoveredBikesHub.stream()
    }

    public func disconnect() async throws {
        await connectionHub.send(BikeConnection(state: .disconnected(reason: "Debug disconnect")))
        await publishDebugEvent(title: "Emulator", detail: "Disconnected")
    }

    public func retrySecurityHandshake() async throws {
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Security handshake simulated")
    }

    public func readTelemetrySnapshot() async throws {
        await publishCurrentState()
    }

    public func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetryHub.stream()
    }

    public func observeConnection() async -> AsyncStream<BikeConnection> {
        await connectionHub.stream()
    }

    public func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        await debugEventHub.stream()
    }

    public func startBatteryHealthMonitoring() async throws {
        isBatteryHealthMonitoring = true
        await publishBatteryHealth()
        await captureHub.replace(with: makeCaptures(date: Date()))
    }

    public func stopBatteryHealthMonitoring() async {
        isBatteryHealthMonitoring = false
    }

    public func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthHub.stream()
    }

    public func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        await captureHub.stream()
    }

    public func setScenario(_ scenario: BikeEmulatorScenario) async {
        self.scenario = scenario
        tick = 0
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Scenario: \(scenario.displayName)")
    }

    public func currentScenario() -> BikeEmulatorScenario {
        scenario
    }

    private func scheduleUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Constants.updateIntervalNanoseconds)
                guard !Task.isCancelled else { return }
                await self?.advance()
            }
        }
    }

    private func advance() async {
        guard isStarted else { return }
        tick += 1
        await publishCurrentState()
    }

    private func publishCurrentState() async {
        let date = Date()
        await connectionHub.send(makeConnection())
        await telemetryHub.send(makeTelemetry(date: date))
        guard isBatteryHealthMonitoring else { return }
        await publishBatteryHealth(date: date)
        await captureHub.replace(with: makeCaptures(date: date))
    }

    private func publishBatteryHealth(date: Date = Date()) async {
        await batteryHealthHub.send(makeBatteryHealth(date: date))
    }

    private func publishDebugEvent(title: String, detail: String) async {
        await debugEventHub.send(BikeDebugEvent(title: title, detail: detail))
    }

    private func makeConnection() -> BikeConnection {
        BikeEmulatorPayloadFactory.makeConnection()
    }

    private func makeTelemetry(date: Date) -> BikeTelemetry {
        BikeEmulatorPayloadFactory.makeTelemetry(scenario: scenario, tick: tick, date: date)
    }

    private func makeBatteryHealth(date: Date) -> BikeBatteryHealth {
        BikeEmulatorPayloadFactory.makeBatteryHealth(scenario: scenario, tick: tick, date: date)
    }

    private func makeCaptures(date: Date) -> [BatteryDatasetCapture] {
        BikeEmulatorPayloadFactory.makeCaptures(scenario: scenario, tick: tick, date: date)
    }

    private enum Constants {
        static let updateIntervalNanoseconds: UInt64 = 400_000_000
    }
}
