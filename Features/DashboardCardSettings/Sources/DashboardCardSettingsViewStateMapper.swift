import BikeDomain
import Foundation
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
                    title: .dashboardCardSettingsFixedSpeedometerTitle,
                    detail: .dashboardCardSettingsFixedSpeedometerDetail,
                    thumbnail: .init(style: .gauge, systemImage: "speedometer", accent: .accent)
                ),
                .init(
                    id: "charging",
                    title: .dashboardCardSettingsFixedChargingTitle,
                    detail: .dashboardCardSettingsFixedChargingDetail,
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
        let bikeLockRequiresPIN = configuration.id == .bikeLock
            && settings.bikeLockSettings(
                forVIN: bikeLockCapability.vehicleIdentifier
            ).securityMode.requiresPIN
        let visibleCount = pages.filter(\.isVisible).count
        let firstVisibleTitle = pages.first(where: \.isVisible)?.title
            ?? pages.first?.title
            ?? .dashboardCardSettingsGenericCardTitle
        let detail = sectionDetail(
            configuration.id,
            pages: pages,
            visibleCount: visibleCount,
            firstVisibleTitle: firstVisibleTitle,
            bikeLockIsConfigured: bikeLockRequiresPIN
        )
        return .init(
            id: configuration.id.rawValue,
            title: sectionTitle(configuration.id),
            detail: detail,
            isVisible: configuration.isVisible || bikeLockRequiresPIN,
            isVisibilityEnabled: !bikeLockRequiresPIN,
            disabledVisibilityHint: bikeLockRequiresPIN
                ? .dashboardCardSettingsBikeLockVisibilityHint
                : nil,
            thumbnail: sectionThumbnail(configuration.id),
            pages: pages
        )
    }

    private func sectionDetail(
        _ id: DashboardCardSectionID,
        pages: [DashboardCardPageRowViewData],
        visibleCount: Int,
        firstVisibleTitle: LocalizedStringResource,
        bikeLockIsConfigured: Bool
    ) -> LocalizedStringResource {
        switch id {
        case .bikeLock:
            bikeLockIsConfigured
                ? .dashboardCardSettingsBikeLockRequiredDetail
                : .dashboardCardSettingsBikeLockDetail
        case .navigation:
            .dashboardCardSettingsNavigationDetail
        default:
            .dashboardCardSettingsSectionVisibleSummary(
                visibleCount,
                String(pages.count),
                String(localized: firstVisibleTitle)
            )
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

    private func sectionTitle(_ id: DashboardCardSectionID) -> LocalizedStringResource {
        switch id {
        case .bikeLock: .dashboardCardSettingsSectionBikeLock
        case .navigation: .dashboardCardSettingsSectionNavigation
        case .currentTrip: .dashboardCardSettingsSectionCurrentTrip
        case .efficiency: .dashboardCardSettingsSectionEfficiency
        case .range: .dashboardCardSettingsSectionRange
        case .systemHealth: .dashboardCardSettingsSectionSystemHealth
        case .rideDynamics: .dashboardCardSettingsSectionRideDynamics
        }
    }

    private func pageTitle(_ id: DashboardCardPageID) -> LocalizedStringResource {
        switch id {
        case .currentTrip: .dashboardCardSettingsPageCurrentTrip
        case .rideStatistics: .dashboardCardSettingsPageRideStatistics
        case .efficiencyLive: .dashboardCardSettingsPageEfficiencyLive
        case .efficiencyTrend: .dashboardCardSettingsPageEfficiencyTrend
        case .range: .dashboardCardSettingsPageRange
        case .batteryTrip: .dashboardCardSettingsPageBatteryTrip
        case .systemHealth: .dashboardCardSettingsPageSystemHealth
        case .batteryCells: .dashboardCardSettingsPageBatteryCells
        case .thermal: .dashboardCardSettingsPageThermal
        case .lean: .dashboardCardSettingsPageLean
        case .pitch: .dashboardCardSettingsPagePitch
        case .course: .dashboardCardSettingsPageCourse
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
