import Foundation

public enum BatteryHealthDestination: String, CaseIterable, Hashable, Sendable {
    case overview
    case cells
    case thermal
    case charging
    case rawData

    public var title: String {
        switch self {
        case .overview: String(localized: .batteryHealthTitle)
        case .cells: String(localized: .batteryHealthSectionCells)
        case .thermal: String(localized: .batteryHealthDestinationThermal)
        case .charging: String(localized: .batteryHealthSectionCharging)
        case .rawData: String(localized: .batteryHealthDestinationRawData)
        }
    }
}
