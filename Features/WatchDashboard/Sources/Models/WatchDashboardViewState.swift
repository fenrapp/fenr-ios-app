import Foundation

public struct WatchDashboardViewState: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case unavailable(detail: String)
        case ride
        case charging
    }

    public let mode: Mode
    public let batteryPercent: Int?
    public let gear: String
    public let odometer: String?
    public let chargingPower: String?
    public let chargingCurrent: String?
    public let batteryTemperature: String?
    public let chargeETA: String?

    public init(
        mode: Mode? = nil,
        batteryPercent: Int? = nil,
        gear: String = "--",
        odometer: String? = nil,
        chargingPower: String? = nil,
        chargingCurrent: String? = nil,
        batteryTemperature: String? = nil,
        chargeETA: String? = nil
    ) {
        self.mode = mode ?? .unavailable(
            detail: String(localized: .watchDashboardConnectionWaitingTelemetry)
        )
        self.batteryPercent = batteryPercent
        self.gear = gear
        self.odometer = odometer
        self.chargingPower = chargingPower
        self.chargingCurrent = chargingCurrent
        self.batteryTemperature = batteryTemperature
        self.chargeETA = chargeETA
    }
}
