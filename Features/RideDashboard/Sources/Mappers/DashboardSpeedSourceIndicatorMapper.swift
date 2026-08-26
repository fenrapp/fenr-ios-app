import SettingsDomain

public struct DashboardSpeedSourceIndicatorMapper: Sendable {
    public init() {}

    public func map(
        _ source: SpeedSource,
        isGPSAvailable: Bool = true
    ) -> DashboardSpeedSourceIndicatorViewData? {
        guard source != .motorcycle else { return nil }
        guard isGPSAvailable else {
            return .init(
                text: "NO GPS",
                systemImage: "location.slash.fill",
                emphasis: .warning
            )
        }
        return switch source {
        case .motorcycle:
            nil
        case .gps:
            .init(text: "GPS", systemImage: "location.fill")
        case .hybrid:
            .init(text: "GPS+", systemImage: "arrow.triangle.branch")
        }
    }
}
