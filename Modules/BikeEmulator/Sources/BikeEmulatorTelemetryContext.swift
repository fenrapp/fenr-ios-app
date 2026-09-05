import Foundation

struct BikeEmulatorTelemetryContext {
    let powerModePreset: BikeEmulatorPowerModePreset
    let activeMapNumber: Int
    let chargeTargetPercent: Int
    let date: Date
    var vin: String = BikeEmulatorIdentity.vin
    var distanceKilometers: Double?
    var chargePowerWatts: Int?
    var isDemo = false
}
