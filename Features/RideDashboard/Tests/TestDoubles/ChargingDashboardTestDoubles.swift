import BikeDomain
import Foundation
import TestSupport

actor ChargingDashboardRepository: BikeRepository, BikeBatteryHealthRepository,
    BikeChargePowerControlRepository {
    private let telemetryHub = TestEventHub<BikeTelemetry>(bufferingPolicy: .unbounded)
    private var failsNextPreparation = false

    func failNextChargePreparation() { failsNextPreparation = true }

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

    func startBatteryHealthMonitoring() async throws {}
    func stopBatteryHealthMonitoring() async {}

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        AsyncStream { _ in }
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        AsyncStream { _ in }
    }

    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        if failsNextPreparation {
            failsNextPreparation = false
            throw PreparationFailure.requested
        }
        return .init(
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
        _ = await telemetryHub.waitForSubscriber()
        await telemetryHub.send(telemetry)
    }

    private enum PreparationFailure: Error {
        case requested
    }

}
