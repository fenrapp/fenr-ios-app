import Foundation

public struct BikeSDKChargePowerTelemetryContext: Equatable, Sendable {
    public let requestedCurrentAmperes: Double
    public let maximumCurrentAmperes: Double
    public let maximumPowerWatts: Double
    public let maximumStateOfChargePercent: Int
    public let chargerTypeRaw: Int

    public init(
        requestedCurrentAmperes: Double,
        maximumCurrentAmperes: Double,
        maximumPowerWatts: Double,
        maximumStateOfChargePercent: Int,
        chargerTypeRaw: Int
    ) {
        self.requestedCurrentAmperes = requestedCurrentAmperes
        self.maximumCurrentAmperes = maximumCurrentAmperes
        self.maximumPowerWatts = maximumPowerWatts
        self.maximumStateOfChargePercent = maximumStateOfChargePercent
        self.chargerTypeRaw = chargerTypeRaw
    }
}
