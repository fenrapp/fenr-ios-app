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
                text: rideDashboardLocalized(.rideDashboardSpeedSourceNoGPS),
                systemImage: "location.slash.fill",
                emphasis: .warning
            )
        }
        return switch source {
        case .motorcycle:
            nil
        case .gps:
            .init(text: rideDashboardLocalized(.rideDashboardSpeedSourceGps), systemImage: "location.fill")
        case .hybrid:
            .init(text: rideDashboardLocalized(.rideDashboardSpeedSourceHybrid), systemImage: "arrow.triangle.branch")
        }
    }
}
