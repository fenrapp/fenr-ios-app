import BikeDomain

public struct ChargingPreferencesState: Equatable, Sendable {
    public var preferences = BikeChargingPreferences()
    public var hasBike = false
    public var isConnected = false
    public var isReading = false
    public var isApplying = false
    public var hasFreshConfiguration = false
    public var connectedCharger: BikeChargerType?
    public var isChargerConnected = false
    public var failure: Failure?

    public init() {}

    public var effectiveCharger: BikeChargerType? {
        isChargerConnected ? connectedCharger : preferences.selectedCharger
    }

    public enum Failure: Equatable, Sendable {
        case storage
        case unavailable
        case incompatibleFirmware
        case confirmation
        case chargerChanged
        case invalidValue
    }
}

public struct ChargingConnectionContext: Equatable, Sendable {
    public let vin: String?
    public let isReady: Bool
    public let isChargerConnected: Bool
    public let charger: BikeChargerType?

    public init(vin: String?, isReady: Bool, isChargerConnected: Bool, charger: BikeChargerType?) {
        self.vin = vin
        self.isReady = isReady
        self.isChargerConnected = isChargerConnected
        self.charger = charger
    }
}
