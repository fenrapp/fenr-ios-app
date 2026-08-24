import BikeDomain
import Foundation
import TestSupport

actor FakeBatteryHealthRepository: BikeBatteryHealthRepository {
    private let healthHub = TestEventHub<BikeBatteryHealth>()
    private let captureHub = TestEventHub<BatteryDatasetCapture>()
    private var latestHealth = BikeBatteryHealth()
    private var didStartMonitoring = false
    private var didStopMonitoring = false
    private var prepareCount = 0
    private var writtenWatts: [Int] = []
    private var writtenTargetPercents: [Int] = []

    func startBatteryHealthMonitoring() async throws {
        didStartMonitoring = true
    }

    func stopBatteryHealthMonitoring() async {
        didStopMonitoring = true
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
        await healthHub.waitForSubscriber()
        await healthHub.send(health)
    }

    func sendCapture(_ capture: BatteryDatasetCapture) async {
        await captureHub.waitForSubscriber()
        await captureHub.send(capture)
    }

    func monitoringStarted() -> Bool { didStartMonitoring }
    func monitoringStopped() -> Bool { didStopMonitoring }
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
}
