import BikeDomain
import Foundation
import SettingsDomain
import TestSupport

actor ChargingDashboardSettingsRepository: AppSettingsRepository {
    func load() async -> AppSettings { .init() }
    func save(_: AppSettings) async {}
    func observe() async -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(.init())
        }
    }
}

actor ChargingDashboardRepository: BikeRepository, BikeBatteryHealthRepository {
    private let telemetryHub = TestEventHub<BikeTelemetry>()
    private let batteryHealthHub = TestEventHub<BikeBatteryHealth>()
    private var starts = 0
    private var stops = 0
    private var stopsAreSuspended = false
    private var stopWaiters: [CheckedContinuation<Void, Never>] = []

    func start() async {}
    func stop() async {}
    func connect(vin: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}

    func observeTelemetry() async -> AsyncStream<BikeTelemetry> {
        await telemetryHub.stream()
    }

    func observeConnection() async -> AsyncStream<BikeConnection> {
        AsyncStream { _ in }
    }

    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> {
        AsyncStream { _ in }
    }

    func startBatteryHealthMonitoring() async throws {
        starts += 1
    }

    func stopBatteryHealthMonitoring() async {
        stops += 1
        if stopsAreSuspended {
            await withCheckedContinuation { stopWaiters.append($0) }
        }
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthHub.stream()
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        AsyncStream { _ in }
    }

    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.12.0",
            isFirmwareCompatible: true,
            readRequestHex: "00 04",
            readResponseHex: "01 04",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 20,
                chargePowerWatts: Int(chargingStatus.maximumPowerWatts),
                maximumStateOfChargeDeciPercent: chargingStatus.maximumStateOfChargePercent * 10,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: "01 04 01",
            didPassNoOpWrite: true,
            logLines: []
        )
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async {
        await telemetryHub.waitForSubscriber()
        await telemetryHub.send(telemetry)
    }

    func sendBatteryHealth(_ health: BikeBatteryHealth) async {
        await batteryHealthHub.waitForSubscriber()
        await batteryHealthHub.send(health)
    }

    func monitoringStartCount() -> Int { starts }
    func monitoringStopCount() -> Int { stops }

    func suspendMonitoringStops() {
        stopsAreSuspended = true
    }

    func resumeMonitoringStops() {
        stopsAreSuspended = false
        let waiters = stopWaiters
        stopWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}
