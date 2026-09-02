import BikeDomain
import Foundation

extension BatteryDataset {
    var displayName: String {
        switch self {
        case .bmsStatus: String(localized: .batteryHealthDatasetBmsStatus)
        case .temperatures: String(localized: .batteryHealthDatasetTemperatures)
        case .dcBus: String(localized: .batteryHealthDatasetDcBus)
        case .cellVoltages: String(localized: .batteryHealthDatasetCellVoltages)
        case .balancing: String(localized: .batteryHealthDatasetBalancing)
        case .signals: String(localized: .batteryHealthDatasetBmsSignals)
        case .charger: String(localized: .batteryHealthDatasetCharger)
        }
    }
}
