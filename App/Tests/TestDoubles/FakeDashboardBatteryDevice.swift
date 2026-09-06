import UIKit

@MainActor
final class FakeDashboardBatteryDevice: UIDevice {
    private var monitoringEnabled = false

    override var isBatteryMonitoringEnabled: Bool {
        get { monitoringEnabled }
        set { monitoringEnabled = newValue }
    }

    override var batteryLevel: Float { 0.5 }
    override var batteryState: UIDevice.BatteryState { .unplugged }
}
