public enum BikeEmulatorScenario: String, CaseIterable, Equatable, Sendable, Identifiable {
    case riding
    case charging
    case cellBalancing
    case chargerIdle
    case chargingDataUnavailable
    case cellAnomaly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .riding: "Riding"
        case .charging: "Normal charging"
        case .cellBalancing: "Cell balancing"
        case .chargerIdle: "Charger idle"
        case .chargingDataUnavailable: "Charging data unavailable"
        case .cellAnomaly: "Cell anomaly"
        }
    }

    public var isCharging: Bool {
        switch self {
        case .charging, .cellBalancing, .chargingDataUnavailable: true
        case .riding, .chargerIdle, .cellAnomaly: false
        }
    }

    public var isChargerConnected: Bool {
        switch self {
        case .charging, .cellBalancing, .chargerIdle, .chargingDataUnavailable: true
        case .riding, .cellAnomaly: false
        }
    }

    public var supportsChargeControl: Bool {
        switch self {
        case .charging, .cellBalancing, .chargerIdle: true
        case .riding, .chargingDataUnavailable, .cellAnomaly: false
        }
    }
}
