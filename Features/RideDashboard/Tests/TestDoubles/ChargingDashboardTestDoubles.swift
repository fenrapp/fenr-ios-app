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
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await batteryHealthHub.stream()
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        AsyncStream { _ in }
    }

    func sendTelemetry(_ telemetry: BikeTelemetry) async {
        await telemetryHub.waitForSubscriber()
        await telemetryHub.send(telemetry)
    }

    func monitoringStartCount() -> Int { starts }
    func monitoringStopCount() -> Int { stops }
}
