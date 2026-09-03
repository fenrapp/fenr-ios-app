import Foundation

public enum BatteryHealthOverallStatus: Equatable, Sendable {
    case collecting
    case healthy
    case attention
    case critical
    case unavailable

    public var text: String {
        switch self {
        case .collecting: String(localized: .batteryHealthStatusCollecting)
        case .healthy: String(localized: .batteryHealthStatusHealthy)
        case .attention: String(localized: .batteryHealthSectionAttention)
        case .critical: String(localized: .batteryHealthCellConditionCritical)
        case .unavailable: String(localized: .batteryHealthStatusUnavailable)
        }
    }

    public var emphasis: BatteryHealthStatusEmphasis {
        switch self {
        case .collecting, .unavailable: .neutral
        case .healthy: .positive
        case .attention: .warning
        case .critical: .critical
        }
    }
}
