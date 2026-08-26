import Foundation

struct BikeEmulatorTelemetryContext {
    let powerModePreset: BikeEmulatorPowerModePreset
    let activeMapNumber: Int
    let chargeTargetPercent: Int
    let date: Date
}
