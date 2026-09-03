import BikeDomain
import Foundation
import TestSupport

actor FakeBatteryHealthRepository: BikeBatteryHealthRepository, BikeChargePowerControlRepository {
    private let healthHub = TestEventHub<BikeBatteryHealth>(bufferingPolicy: .unbounded)
    private let captureHub = TestEventHub<BatteryDatasetCapture>(bufferingPolicy: .unbounded)
    private var latestHealth = BikeBatteryHealth()
    private var monitoringStarts = 0
    private var monitoringStops = 0
    private var delaysNextMonitoringStart = false
    private var prepareCount = 0
    private var writtenWatts: [Int] = []
    private var writtenTargetPercents: [Int] = []

    func startBatteryHealthMonitoring() async throws {
        if delaysNextMonitoringStart {
            delaysNextMonitoringStart = false
            try? await Task.sleep(for: Constants.delayedMonitoringStartDuration)
        }
        monitoringStarts += 1
    }

    func stopBatteryHealthMonitoring() async {
        monitoringStops += 1
    }

    func observeBatteryHealth() async -> AsyncStream<BikeBatteryHealth> {
        await healthHub.stream(replay: latestHealth)
    }

    func observeBatteryDatasetCaptures() async -> AsyncStream<BatteryDatasetCapture> {
        await captureHub.stream()
    }

    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        prepareCount += 1
        return chargePowerSnapshot(
            watts: Int(chargingStatus.maximumPowerWatts.rounded()),
            writeHex: "01 04 01 50 00 E8 03 E8 03 E4 0C E4 0C"
        )
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        writtenWatts.append(watts)
        return chargePowerSnapshot(watts: watts, writeHex: "01 04 01")
    }

    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        writtenTargetPercents.append(percent)
        return chargePowerSnapshot(targetPercent: percent, writeHex: "01 04 01")
    }

    func sendHealth(_ health: BikeBatteryHealth) async {
        latestHealth = health
        _ = await healthHub.waitForSubscriber()
        await healthHub.send(health)
    }

    func sendCapture(_ capture: BatteryDatasetCapture) async {
        _ = await captureHub.waitForSubscriber()
        await captureHub.send(capture)
    }

    func monitoringStarted() -> Bool { monitoringStarts > 0 }
    func monitoringStopped() -> Bool { monitoringStops > 0 }
    func monitoringStartCount() -> Int { monitoringStarts }
    func monitoringStopCount() -> Int { monitoringStops }
    func delayNextMonitoringStart() { delaysNextMonitoringStart = true }
    func chargePowerPrepareCount() -> Int { prepareCount }
    func chargePowerWrites() -> [Int] { writtenWatts }
    func chargeTargetWrites() -> [Int] { writtenTargetPercents }

    private func chargePowerSnapshot(
        watts: Int = 1_000,
        targetPercent: Int = 100,
        writeHex: String
    ) -> BikeChargePowerControlSnapshot {
        .init(
            vcuFirmware: "1.9.1",
            isFirmwareCompatible: true,
            readRequestHex: "00 04",
            readResponseHex: "01 04 01 50 00 E8 03 E8 03 E4 0C E4 0C",
            parsedConfig: .init(
                chargeCurrentDeciAmperes: 80,
                chargePowerWatts: watts,
                maximumStateOfChargeDeciPercent: targetPercent * 10,
                standardChargerMaximumPowerWatts: 3_300,
                backpackChargerMaximumPowerWatts: 3_300
            ),
            lastWriteHex: writeHex,
            didPassNoOpWrite: true,
            logLines: ["test snapshot"]
        )
    }

    private enum Constants {
        static let delayedMonitoringStartDuration: Duration = .milliseconds(100)
    }
}
