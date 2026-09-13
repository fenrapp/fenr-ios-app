import Foundation

public struct WatchDashboardViewState: Equatable, Sendable {
    public enum BatteryEmphasis: Equatable, Sendable {
        case positive, warning, critical, unavailable
    }

    public let batteryEmphasis: BatteryEmphasis
    public let showsMap: Bool
    public let hasData: Bool
    public let isCharging: Bool
    public let isStale: Bool
    public let status: String
    public let updatedAt: Date?
    public let batteryPercent: Int?
    public let map: String
    public let traction: String
    public let chargingPower: String
    public let chargingCurrent: String
    public let chargeETA: String?

    public init(
        hasData: Bool = false,
        batteryEmphasis: BatteryEmphasis = .unavailable,
        showsMap: Bool = true,
        isCharging: Bool = false,
        isStale: Bool = true,
        status: String? = nil,
        updatedAt: Date? = nil,
        batteryPercent: Int? = nil,
        map: String = "--",
        traction: String = "--",
        chargingPower: String = "--",
        chargingCurrent: String = "--",
        chargeETA: String? = nil
    ) {
        self.batteryEmphasis = batteryEmphasis
        self.showsMap = showsMap
        self.hasData = hasData
        self.isCharging = isCharging
        self.isStale = isStale
        self.status = status ?? String(localized: .watchCompanionOpenPhone)
        self.updatedAt = updatedAt
        self.batteryPercent = batteryPercent
        self.map = map
        self.traction = traction
        self.chargingPower = chargingPower
        self.chargingCurrent = chargingCurrent
        self.chargeETA = chargeETA
    }
}
