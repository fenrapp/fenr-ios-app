public enum BatteryDataset: String, CaseIterable, Equatable, Hashable, Sendable {
    case bmsStatus
    case temperatures
    case dcBus
    case cellVoltages
    case balancing
    case signals
    case charger

    public var displayName: String {
        switch self {
        case .bmsStatus: "BMS status"
        case .temperatures: "Temperatures"
        case .dcBus: "DC bus"
        case .cellVoltages: "Cell voltages"
        case .balancing: "Balancing"
        case .signals: "BMS signals"
        case .charger: "Charger"
        }
    }
}
