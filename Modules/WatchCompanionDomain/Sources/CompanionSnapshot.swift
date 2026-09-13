import Foundation

public struct CompanionSnapshot: Codable, Equatable, Sendable {
    public enum Activity: String, Codable, Sendable {
        case off, neutral, riding, charging, crawl, unknown
    }

    public let activity: Activity?
    public let mapName: String?
    public let version: Int
    public let generatedAt: Date
    public let telemetryAt: Date?
    public let bikeConnected: Bool
    public let isCharging: Bool
    public let batteryPercent: Int?
    public let mapIndex: Int?
    public let tractionPercent: Double?
    public let chargingPowerWatts: Double?
    public let chargingCurrentAmperes: Double?
    public let chargeRemainingSeconds: Double?

    public init(
        generatedAt: Date,
        telemetryAt: Date? = nil,
        bikeConnected: Bool = false,
        isCharging: Bool = false,
        batteryPercent: Int? = nil,
        mapIndex: Int? = nil,
        mapName: String? = nil,
        activity: Activity? = nil,
        tractionPercent: Double? = nil,
        chargingPowerWatts: Double? = nil,
        chargingCurrentAmperes: Double? = nil,
        chargeRemainingSeconds: Double? = nil
    ) {
        self.activity = activity
        self.mapName = mapName
        version = 1
        self.generatedAt = generatedAt
        self.telemetryAt = telemetryAt
        self.bikeConnected = bikeConnected
        self.isCharging = isCharging
        self.batteryPercent = batteryPercent
        self.mapIndex = mapIndex
        self.tractionPercent = tractionPercent
        self.chargingPowerWatts = chargingPowerWatts
        self.chargingCurrentAmperes = chargingCurrentAmperes
        self.chargeRemainingSeconds = chargeRemainingSeconds
    }
}
