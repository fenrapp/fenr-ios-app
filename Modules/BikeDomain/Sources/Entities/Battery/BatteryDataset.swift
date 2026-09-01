public enum BatteryDataset: String, CaseIterable, Equatable, Hashable, Sendable {
    case bmsStatus
    case temperatures
    case dcBus
    case cellVoltages
    case balancing
    case signals
    case charger

}
