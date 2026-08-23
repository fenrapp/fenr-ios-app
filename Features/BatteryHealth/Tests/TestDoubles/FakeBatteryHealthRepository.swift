import BikeDomain
import Foundation
import TestSupport

actor FakeBatteryHealthRepository: BikeBatteryHealthRepository {
    private let healthHub = TestEventHub<BikeBatteryHealth>()
    private let captureHub = TestEventHub<BatteryDatasetCapture>()
    private var latestHealth = BikeBatteryHealth()
    private var didStartMonitoring = false
    private var didStopMonitoring = false

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
}
