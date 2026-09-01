import BikeDomain

extension BatteryDataset {
    var displayName: String {
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
