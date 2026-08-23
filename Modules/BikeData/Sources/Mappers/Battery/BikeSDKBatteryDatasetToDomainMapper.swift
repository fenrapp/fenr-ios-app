import BikeDomain
import BikeSDK

public struct BikeSDKBatteryDatasetToDomainMapper: Sendable {
    public init() {}

    public func map(_ dataset: BikeSDKBatteryDataset) -> BatteryDataset {
        switch dataset {
        case .bmsStatus: .bmsStatus
        case .temperatures: .temperatures
        case .dcBus: .dcBus
        case .cellVoltages: .cellVoltages
        case .balancing: .balancing
        case .signals: .signals
        case .charger: .charger
        }
    }
}
