import BikeDomain
import Foundation
import RuntimeConfiguration

public actor BikeEmulatorRepository: BikeRepository, BikeBatteryHealthRepository, BikeDiscoveryRepository {
    private let telemetryHub: BikeEmulatorEventHub<BikeTelemetry>
    private let connectionHub: BikeEmulatorEventHub<BikeConnection>
    private let debugEventHub: BikeEmulatorEventHub<BikeDebugEvent>
    private let batteryHealthHub: BikeEmulatorEventHub<BikeBatteryHealth>
    private let captureHub: BikeEmulatorCaptureHub
    private let discoveredBikesHub: BikeEmulatorEventHub<[DiscoveredBike]>

    private var scenario: BikeEmulatorScenario
    private var powerModePreset: BikeEmulatorPowerModePreset
    private var activeMapNumber: Int
    private var tick = 0
    private var isStarted = false
    private var batteryHealthMonitoringLeaseCount = 0
    private var chargePowerLimitWatts = Constants.defaultChargePowerWatts
    private var chargeTargetPercent = Constants.defaultChargeTargetPercent
    private var updateTask: Task<Void, Never>?

    init(
        scenario: BikeEmulatorScenario,
        powerModePreset: BikeEmulatorPowerModePreset,
        activeMapNumber: Int,
        channels: BikeEmulatorChannels
    ) {
        self.scenario = scenario
        self.powerModePreset = powerModePreset
        self.activeMapNumber = max(1, min(5, activeMapNumber))
        telemetryHub = channels.telemetry
        connectionHub = channels.connection
        debugEventHub = channels.debugEvent
        batteryHealthHub = channels.batteryHealth
        captureHub = channels.capture
        discoveredBikesHub = channels.discoveredBikes
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

    public func refreshPowerModeConfigurations() async throws {
        guard powerModePreset != .failure else {
            await publishDebugEvent(title: "Power modes", detail: "Simulated 4005 timeout")
            throw BikeEmulatorPowerModeError.readFailure
        }
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
        batteryHealthMonitoringLeaseCount += 1
        await publishBatteryHealth()
        await captureHub.replace(with: makeCaptures(date: Date()))
    }

    public func stopBatteryHealthMonitoring() async {
        batteryHealthMonitoringLeaseCount = max(0, batteryHealthMonitoringLeaseCount - 1)
    }

    public func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthHub.stream()
    }

    public func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        await captureHub.stream()
    }

    public func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        guard scenario.supportsChargeControl else { throw BikeEmulatorChargeControlError.chargerUnavailable }
        return makeChargeControlSnapshot(
            watts: Int(chargingStatus.maximumPowerWatts.rounded()),
            targetPercent: chargingStatus.maximumStateOfChargePercent,
            lastWriteHex: Constants.noOpWriteHex
        )
    }

    public func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        guard scenario.supportsChargeControl else { throw BikeEmulatorChargeControlError.chargerUnavailable }
        guard Constants.minimumChargePowerWatts ... Constants.maximumChargePowerWatts ~= watts else {
            throw BikeEmulatorChargeControlError.invalidPower
        }
        chargePowerLimitWatts = watts
        await publishBatteryHealth()
        return makeChargeControlSnapshot(
            watts: watts,
            targetPercent: chargeTargetPercent,
            lastWriteHex: "DEBUG POWER \(watts)"
        )
    }

    public func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        guard scenario.supportsChargeControl else { throw BikeEmulatorChargeControlError.chargerUnavailable }
        guard Constants.minimumChargeTargetPercent ... Constants.maximumChargeTargetPercent ~= percent else {
            throw BikeEmulatorChargeControlError.invalidTarget
        }
        chargeTargetPercent = percent
        await publishBatteryHealth()
        return makeChargeControlSnapshot(
            watts: chargePowerLimitWatts,
            targetPercent: percent,
            lastWriteHex: "DEBUG TARGET \(percent)"
        )
    }

    public func setScenario(_ scenario: BikeEmulatorScenario) async {
        self.scenario = scenario
        tick = 0
        chargePowerLimitWatts = Constants.defaultChargePowerWatts
        chargeTargetPercent = Constants.defaultChargeTargetPercent
        await publishCurrentState()
        await publishDebugEvent(title: "Emulator", detail: "Scenario: \(scenario.displayName)")
    }

    public func currentScenario() -> BikeEmulatorScenario {
        scenario
    }

    public func setPowerModePreset(_ preset: BikeEmulatorPowerModePreset) async {
        powerModePreset = preset
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Preset: \(preset.displayName)")
    }

    public func setActiveMap(_ visibleMap: Int) async {
        activeMapNumber = max(1, min(5, visibleMap))
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Active map: \(activeMapNumber)")
    }

    private func scheduleUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: FENRRuntimeConstants.Emulator.updateInterval)
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
        guard batteryHealthMonitoringLeaseCount > 0 else { return }
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
        BikeEmulatorPayloadFactory.makeTelemetry(
            scenario: scenario,
            powerModePreset: powerModePreset,
            activeMapNumber: activeMapNumber,
            tick: tick,
            date: date
        )
    }

    private func makeBatteryHealth(date: Date) -> BikeBatteryHealth {
        BikeEmulatorPayloadFactory.makeBatteryHealth(
            scenario: scenario,
            tick: tick,
            date: date,
            chargePowerLimitWatts: chargePowerLimitWatts,
            chargeTargetPercent: chargeTargetPercent
        )
    }

    private func makeCaptures(date: Date) -> [BatteryDatasetCapture] {
        BikeEmulatorPayloadFactory.makeCaptures(scenario: scenario, tick: tick, date: date)
    }

    private func makeChargeControlSnapshot(
        watts: Int,
        targetPercent: Int,
        lastWriteHex: String
    ) -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0",
            isFirmwareCompatible: true,
            readRequestHex: "DEBUG READ 4005",
            readResponseHex: "DEBUG POWER \(watts) TARGET \(targetPercent)",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: Int((Double(watts) / Constants.chargingBusVoltage * 10).rounded()),
                chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: targetPercent * 10,
                standardChargerMaximumPowerWatts: Constants.maximumChargePowerWatts,
                backpackChargerMaximumPowerWatts: Constants.maximumChargePowerWatts
            ),
            lastWriteHex: lastWriteHex,
            didPassNoOpWrite: true,
            logLines: ["Debug charge control confirmed"]
        )
    }

    private enum Constants {
        static let defaultChargePowerWatts = 1_000
        static let defaultChargeTargetPercent = 100
        static let minimumChargePowerWatts = 300
        static let maximumChargePowerWatts = 3_300
        static let minimumChargeTargetPercent = 1
        static let maximumChargeTargetPercent = 100
        static let chargingBusVoltage = 388.4
        static let noOpWriteHex = "DEBUG NO-OP 4005"
    }
}

private enum BikeEmulatorChargeControlError: Error {
    case chargerUnavailable
    case invalidPower
    case invalidTarget
}

private enum BikeEmulatorPowerModeError: LocalizedError {
    case readFailure

    var errorDescription: String? { "Simulated 4005 read timeout" }
}
