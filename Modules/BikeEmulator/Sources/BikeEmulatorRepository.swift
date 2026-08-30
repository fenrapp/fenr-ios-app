import BikeDomain
import Foundation
import RuntimeConfiguration

// The emulator keeps one actor as the owner of every simulated bike channel.
// swiftlint:disable file_length type_body_length

public actor BikeEmulatorRepository: BikeRepository, BikeIMURepository, BikeBatteryHealthRepository,
    BikeChargePowerControlRepository, BikeDiscoveryRepository {
    private let telemetryHub: BikeEmulatorEventHub<BikeTelemetry>
    private let connectionHub: BikeEmulatorEventHub<BikeConnection>
    private let imuHub: BikeEmulatorEventHub<BikeIMUSample>
    let debugEventHub: BikeEmulatorEventHub<BikeDebugEvent>
    private let batteryHealthHub: BikeEmulatorEventHub<BikeBatteryHealth>
    private let captureHub: BikeEmulatorCaptureHub
    private let discoveredBikesHub: BikeEmulatorEventHub<[DiscoveredBike]>
    private let powerCalculator: BikePowerTelemetryCalculator

    private var scenario: BikeEmulatorScenario
    private var powerModePreset: BikeEmulatorPowerModePreset
    private var activeMapNumber: Int
    private var tick = 0
    private var isStarted = false
    private var batteryHealthMonitoringLeaseCount = 0
    private var imuMonitoringLeaseCount = 0
    private var chargePowerLimitWatts = Constants.defaultChargePowerWatts
    private var chargeTargetPercent = Constants.defaultChargeTargetPercent
    private var powerModeOverrides: [Int: BikePowerModeConfiguration] = [:]
    private var preparedPowerModeIndexes = Set<Int>()
    private var preparedTractionControlIndexes = Set<Int>()
    var isBikeLockPrepared = false
    var isBikeLocked = false
    private var lastPublishedConnection: BikeConnection?
    private var updateTask: Task<Void, Never>?
    private var imuUpdateTask: Task<Void, Never>?

    init(
        scenario: BikeEmulatorScenario,
        powerModePreset: BikeEmulatorPowerModePreset,
        activeMapNumber: Int,
        channels: BikeEmulatorChannels,
        powerCalculator: BikePowerTelemetryCalculator
    ) {
        self.scenario = scenario
        self.powerModePreset = powerModePreset
        self.activeMapNumber = max(1, min(5, activeMapNumber))
        telemetryHub = channels.telemetry
        connectionHub = channels.connection
        imuHub = channels.imu
        debugEventHub = channels.debugEvent
        batteryHealthHub = channels.batteryHealth
        captureHub = channels.capture
        discoveredBikesHub = channels.discoveredBikes
        self.powerCalculator = powerCalculator
    }

    deinit {
        updateTask?.cancel()
        imuUpdateTask?.cancel()
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
        imuUpdateTask?.cancel()
        imuUpdateTask = nil
        imuMonitoringLeaseCount = 0
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
        isBikeLockPrepared = false
        await publishConnectionIfChanged(
            BikeConnection(state: .disconnected(reason: "Debug disconnect"))
        )
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

    public func preparePowerModeControl(mapIndex: Int) async throws {
        guard currentPowerModeConfigurations()[mapIndex]?.hasBaseConfiguration == true else {
            throw BikeEmulatorPowerModeError.readFailure
        }
        preparedPowerModeIndexes.insert(mapIndex)
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug no-op confirmed for map \(mapIndex + 1)"
        )
    }

    public func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        guard preparedPowerModeIndexes.contains(mapIndex),
              var configuration = currentPowerModeConfigurations()[mapIndex]
        else {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        guard Constants.powerModeHorsepowerRange.contains(horsepower),
              Constants.powerModeRegenerationRange.contains(regenerativeBrakingPercent)
        else {
            throw BikeEmulatorPowerModeError.invalidConfiguration
        }
        configuration.horsepower = horsepower
        configuration.regenerativeBrakingPercent = Double(regenerativeBrakingPercent)
        powerModeOverrides[mapIndex] = configuration
        await publishCurrentState()
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug map \(mapIndex + 1) write confirmed"
        )
    }

    public func prepareTractionControl(mapIndex: Int) async throws {
        guard currentPowerModeConfigurations()[mapIndex]?.hasTractionControlConfiguration == true else {
            throw BikeEmulatorPowerModeError.readFailure
        }
        preparedTractionControlIndexes.insert(mapIndex)
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug TC no-op confirmed for map \(mapIndex + 1)"
        )
    }

    public func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        guard preparedTractionControlIndexes.contains(mapIndex),
              var configuration = currentPowerModeConfigurations()[mapIndex]
        else {
            throw BikeEmulatorPowerModeError.controlNotPrepared
        }
        guard Constants.tractionControlRange.contains(powerTractionPercent),
              Constants.tractionControlRange.contains(brakingTractionPercent),
              powerTractionPercent.rounded() == powerTractionPercent,
              brakingTractionPercent.rounded() == brakingTractionPercent
        else {
            throw BikeEmulatorPowerModeError.invalidConfiguration
        }
        configuration.powerTractionPercent = powerTractionPercent
        configuration.brakingTractionPercent = brakingTractionPercent
        powerModeOverrides[mapIndex] = configuration
        await publishCurrentState()
        await publishDebugEvent(
            title: "Power modes",
            detail: "Debug TC map \(mapIndex + 1) write confirmed"
        )
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

    public func observeIMU() async -> AsyncStream<BikeIMUSample> {
        await imuHub.stream()
    }

    public func startIMUMonitoring() {
        imuMonitoringLeaseCount += 1
        guard imuMonitoringLeaseCount == 1 else { return }
        scheduleIMUUpdates()
    }

    public func stopIMUMonitoring() {
        imuMonitoringLeaseCount = max(0, imuMonitoringLeaseCount - 1)
        guard imuMonitoringLeaseCount == 0 else { return }
        imuUpdateTask?.cancel()
        imuUpdateTask = nil
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
        await publishCurrentState()
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
        powerModeOverrides.removeAll()
        preparedPowerModeIndexes.removeAll()
        preparedTractionControlIndexes.removeAll()
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Preset: \(preset.displayName)")
    }

    public func setActiveMap(_ visibleMap: Int) async {
        activeMapNumber = max(1, min(5, visibleMap))
        await publishCurrentState()
        await publishDebugEvent(title: "Power modes", detail: "Active map: \(activeMapNumber)")
    }

}

private extension BikeEmulatorRepository {
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

    private func scheduleIMUUpdates() {
        imuUpdateTask?.cancel()
        imuUpdateTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.publishIMU()
            }
        }
    }

    private func publishIMU() async {
        let date = Date()
        let phase = date.timeIntervalSinceReferenceDate
        let rollRadians = sin(phase * 0.7) * 12 * .pi / 180
        let pitchRadians = sin(phase * 0.37) * 6 * .pi / 180
        let acceleration = BikeIMUVector(
            x: -sin(pitchRadians) * Constants.debugOneGRaw,
            y: sin(rollRadians) * cos(pitchRadians) * Constants.debugOneGRaw,
            z: cos(rollRadians) * cos(pitchRadians) * Constants.debugOneGRaw
        )
        let gyroscope = BikeIMUVector(
            x: cos(phase * 0.7) * 8.4,
            y: cos(phase * 0.37) * 2.22,
            z: .zero
        )
        await imuHub.send(.init(
            accelerationRaw: acceleration,
            gyroscopeRaw: gyroscope,
            observedAt: date
        ))
    }

    private func advance() async {
        guard isStarted else { return }
        tick += 1
        await publishCurrentState()
    }

    private func publishCurrentState() async {
        let date = Date()
        await publishConnectionIfChanged(makeConnection())
        await telemetryHub.send(makeTelemetry(date: date))
        guard batteryHealthMonitoringLeaseCount > 0 else { return }
        await publishBatteryHealth(date: date)
        await captureHub.replace(with: makeCaptures(date: date))
    }

    private func publishBatteryHealth(date: Date = Date()) async {
        await batteryHealthHub.send(makeBatteryHealth(date: date))
    }

    private func makeConnection() -> BikeConnection {
        BikeEmulatorPayloadFactory.makeConnection()
    }

    private func makeTelemetry(date: Date) -> BikeTelemetry {
        var telemetry = BikeEmulatorPayloadFactory.makeTelemetry(
            scenario: scenario,
            tick: tick,
            context: .init(
                powerModePreset: powerModePreset,
                activeMapNumber: activeMapNumber,
                chargeTargetPercent: chargeTargetPercent,
                date: date
            ),
            powerCalculator: powerCalculator
        )
        telemetry.powerModeConfigurations.merge(powerModeOverrides) { _, override in override }
        return telemetry
    }

    private func currentPowerModeConfigurations() -> [Int: BikePowerModeConfiguration] {
        var configurations = BikeEmulatorPowerModeTelemetryFactory.configurations(
            preset: powerModePreset,
            activeMapNumber: activeMapNumber
        )
        configurations.merge(powerModeOverrides) { _, override in override }
        return configurations
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
        static let powerModeHorsepowerRange = 10 ... 80
        static let powerModeRegenerationRange = -100 ... 100
        static let tractionControlRange = 0.0 ... 100.0
        static let debugOneGRaw = 1_000.0
    }
}

private extension BikeEmulatorRepository {
    func publishConnectionIfChanged(_ connection: BikeConnection) async {
        guard connection != lastPublishedConnection else { return }
        lastPublishedConnection = connection
        await connectionHub.send(connection)
    }
}
private enum BikeEmulatorChargeControlError: Error {
    case chargerUnavailable
    case invalidPower
    case invalidTarget
}
// swiftlint:enable file_length type_body_length
