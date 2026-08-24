import Foundation

public struct WatchDashboardViewState: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case unavailable(detail: String)
        case ride
        case charging
    }

    public var mode: Mode
    public var batteryPercent: Int?
    public var gear: String
    public var odometer: String?
    public var chargingPower: String?
    public var chargingCurrent: String?
    public var batteryTemperature: String?
    public var chargeETA: String?

    public init(
        mode: Mode = .unavailable(detail: "Waiting for telemetry"),
        batteryPercent: Int? = nil,
        gear: String = "--",
        odometer: String? = nil,
        chargingPower: String? = nil,
        chargingCurrent: String? = nil,
        batteryTemperature: String? = nil,
        chargeETA: String? = nil
    ) {
        self.mode = mode
        self.batteryPercent = batteryPercent
        self.gear = gear
        self.odometer = odometer
        self.chargingPower = chargingPower
        self.chargingCurrent = chargingCurrent
        self.batteryTemperature = batteryTemperature
        self.chargeETA = chargeETA
    }
}
