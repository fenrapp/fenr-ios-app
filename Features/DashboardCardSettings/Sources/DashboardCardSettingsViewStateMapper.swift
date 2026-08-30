import BikeDomain
import SettingsDomain

public struct DashboardCardSettingsViewStateMapper: Sendable {
    public init() {}

    public func map(
        settings: AppSettings,
        bikeLockCapability: BikeLockCapabilityState
    ) -> DashboardCardSettingsViewState {
        .init(
            fixedCards: [
                .init(
                    id: "speedometer",
                    title: "Speedometer",
                    detail: "Always first while riding",
                    thumbnail: .init(style: .gauge, systemImage: "speedometer", accent: .accent)
                ),
                .init(
                    id: "charging",
                    title: "Charging",
                    detail: "Shown automatically while charging",
                    thumbnail: .init(style: .charging, systemImage: "bolt.fill", accent: .positive)
                )
            ],
            sections: settings.dashboardCardConfiguration.sections.compactMap {
                section($0, settings: settings, bikeLockCapability: bikeLockCapability)
            }
        )
    }

    private func section(
        _ configuration: DashboardCardSectionConfiguration,
        settings: AppSettings,
        bikeLockCapability: BikeLockCapabilityState
    ) -> DashboardCardSectionRowViewData? {
        if configuration.id == .bikeLock, !bikeLockCapability.isAvailable {
            return nil
        }
        let pages = configuration.pages.map { page($0, in: configuration) }
        let bikeLockIsConfigured = configuration.id == .bikeLock
            && settings.bikeLockSettings(
                forVIN: bikeLockCapability.vehicleIdentifier
            ).securityMode.isConfigured
        let visibleCount = pages.filter(\.isVisible).count
        let firstVisibleTitle = pages.first(where: \.isVisible)?.title ?? pages.first?.title ?? ""
        let detail = sectionDetail(
            configuration.id,
            pages: pages,
            visibleCount: visibleCount,
            firstVisibleTitle: firstVisibleTitle,
            bikeLockIsConfigured: bikeLockIsConfigured
        )
        return .init(
            id: configuration.id.rawValue,
            title: sectionTitle(configuration.id),
            detail: detail,
            isVisible: configuration.isVisible || bikeLockIsConfigured,
            isVisibilityEnabled: !bikeLockIsConfigured,
            disabledVisibilityHint: bikeLockIsConfigured
                ? "Bike Lock must remain visible while unlock protection is configured"
                : nil,
            thumbnail: sectionThumbnail(configuration.id),
            pages: pages
        )
    }

    private func sectionDetail(
        _ id: DashboardCardSectionID,
        pages: [DashboardCardPageRowViewData],
        visibleCount: Int,
        firstVisibleTitle: String,
        bikeLockIsConfigured: Bool
    ) -> String {
        switch id {
        case .bikeLock:
            bikeLockIsConfigured
                ? "Required while unlock protection is configured"
                : "Lock and unlock the motorcycle from the dashboard"
        case .navigation:
            "Open ride navigation from the dashboard"
        default:
            "\(visibleCount) of \(pages.count) cards visible · \(firstVisibleTitle) first"
        }
    }

    private func page(
        _ configuration: DashboardCardPageConfiguration,
        in section: DashboardCardSectionConfiguration
    ) -> DashboardCardPageRowViewData {
        .init(
            id: configuration.id.rawValue,
            title: pageTitle(configuration.id),
            isVisible: configuration.isVisible,
            canHide: !configuration.isVisible || section.pages.filter(\.isVisible).count > 1,
            thumbnail: pageThumbnail(configuration.id)
        )
    }

    private func sectionTitle(_ id: DashboardCardSectionID) -> String {
        switch id {
        case .bikeLock: "Bike Lock"
        case .navigation: "Ride Navigation"
        case .currentTrip: "Current Trip"
        case .efficiency: "Efficiency"
        case .range: "Range"
        case .systemHealth: "System Health"
        case .rideDynamics: "Ride Dynamics"
        }
    }

    private func pageTitle(_ id: DashboardCardPageID) -> String {
        switch id {
        case .currentTrip: "Current Trip"
        case .rideStatistics: "Ride Statistics"
        case .efficiencyLive: "Live Efficiency"
        case .efficiencyTrend: "Efficiency Trend"
        case .range: "Range"
        case .batteryTrip: "Battery Trip"
        case .systemHealth: "Health"
        case .batteryCells: "Cells"
        case .thermal: "Thermal"
        case .lean: "Lean"
        case .pitch: "Pitch"
        case .course: "Course"
        }
    }

    private func sectionThumbnail(_ id: DashboardCardSectionID) -> DashboardCardThumbnailViewData {
        switch id {
        case .bikeLock: .init(style: .lock, systemImage: "lock.fill", accent: .accent)
        case .navigation: .init(style: .compass, systemImage: "location.north.fill", accent: .accent)
        case .currentTrip: .init(style: .metrics, systemImage: "timer", accent: .accent)
        case .efficiency: .init(style: .chart, systemImage: "leaf.fill", accent: .positive)
        case .range: .init(style: .battery, systemImage: "road.lanes", accent: .informational)
        case .systemHealth: .init(style: .grid, systemImage: "heart.text.square.fill", accent: .critical)
        case .rideDynamics: .init(style: .attitude, systemImage: "gyroscope", accent: .accent)
        }
    }

    private func pageThumbnail(_ id: DashboardCardPageID) -> DashboardCardThumbnailViewData {
        switch id {
        case .currentTrip: .init(style: .metrics, systemImage: "timer", accent: .accent)
        case .rideStatistics: .init(style: .grid, systemImage: "chart.bar.fill", accent: .accent)
        case .efficiencyLive: .init(style: .gauge, systemImage: "leaf.fill", accent: .positive)
        case .efficiencyTrend: .init(style: .chart, systemImage: "chart.xyaxis.line", accent: .positive)
        case .range: .init(style: .gauge, systemImage: "road.lanes", accent: .informational)
        case .batteryTrip: .init(style: .battery, systemImage: "battery.75percent", accent: .informational)
        case .systemHealth: .init(style: .metrics, systemImage: "heart.fill", accent: .critical)
        case .batteryCells: .init(style: .grid, systemImage: "square.grid.3x3.fill", accent: .critical)
        case .thermal: .init(style: .chart, systemImage: "thermometer.medium", accent: .warning)
        case .lean: .init(style: .attitude, systemImage: "angle", accent: .accent)
        case .pitch: .init(style: .attitude, systemImage: "arrow.up.and.down", accent: .accent)
        case .course: .init(style: .compass, systemImage: "location.north.fill", accent: .accent)
        }
    }
}
