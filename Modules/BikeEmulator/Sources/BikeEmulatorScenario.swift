public enum BikeEmulatorScenario: String, CaseIterable, Equatable, Sendable, Identifiable {
    case riding
    case ridingClean
    case charging
    case cellBalancing
    case chargerIdle
    case chargingDataUnavailable
    case cellAnomaly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .riding: "Riding"
        case .ridingClean: "Riding (no indicators)"
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
        case .riding, .ridingClean, .chargerIdle, .cellAnomaly: false
        }
    }

    public var isRiding: Bool {
        switch self {
        case .riding, .ridingClean: true
        case .charging, .cellBalancing, .chargerIdle, .chargingDataUnavailable, .cellAnomaly: false
        }
    }

    public var isChargerConnected: Bool {
        switch self {
        case .charging, .cellBalancing, .chargerIdle, .chargingDataUnavailable: true
        case .riding, .ridingClean, .cellAnomaly: false
        }
    }

    public var supportsChargeControl: Bool {
        switch self {
        case .charging, .cellBalancing, .chargerIdle: true
        case .riding, .ridingClean, .chargingDataUnavailable, .cellAnomaly: false
        }
    }
}
