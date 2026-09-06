import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Device battery monitor lifecycle")
struct UIKitDashboardDeviceBatteryMonitorTests {
    @Test("Releasing a started monitor restores device monitoring and finishes its streams")
    func releaseRestoresMonitoringAndFinishesStream() async throws {
        let device = FakeDashboardBatteryDevice()
        var monitor: UIKitDashboardDeviceBatteryMonitor? = UIKitDashboardDeviceBatteryMonitor(
            device: device,
            notificationCenter: NotificationCenter()
        )
        let stream = try #require(monitor?.observe())
        var didFinish = false
        let observation = Task {
            for await _ in stream {}
            didFinish = true
        }
        defer { observation.cancel() }
        monitor?.start()
        #expect(device.isBatteryMonitoringEnabled)

        monitor = nil

        #expect(!device.isBatteryMonitoringEnabled)
        #expect(await waitUntil { didFinish })
        observation.cancel()
        await observation.value
    }

    @Test("Repeated start and stop preserve an already enabled monitoring setting")
    func preservesExistingMonitoring() {
        let device = FakeDashboardBatteryDevice()
        device.isBatteryMonitoringEnabled = true
        let monitor = UIKitDashboardDeviceBatteryMonitor(
            device: device,
            notificationCenter: NotificationCenter()
        )

        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()

        #expect(device.isBatteryMonitoringEnabled)
    }
}
