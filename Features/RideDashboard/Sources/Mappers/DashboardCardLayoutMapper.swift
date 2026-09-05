import SettingsDomain

public struct DashboardCardLayoutMapper: Sendable {
    public init() {}

    func map(_ configuration: DashboardCardConfiguration) -> DashboardCardLayout {
        DashboardCardLayout(
            ridingCards: configuration.sections
                .filter { $0.isVisible || $0.id == .bikeLock || $0.id == .settings }
                .map { ridingCard($0.id) },
            currentTripPages: visiblePages(for: .currentTrip, in: configuration).compactMap(currentTripPage),
            efficiencyPages: visiblePages(for: .efficiency, in: configuration).compactMap(efficiencyPage),
            rangePages: visiblePages(for: .range, in: configuration).compactMap(rangePage),
            systemHealthPages: visiblePages(for: .systemHealth, in: configuration).compactMap(systemHealthPage),
            dynamicsPages: visiblePages(for: .rideDynamics, in: configuration).compactMap(dynamicsPage)
        )
    }

    private func visiblePages(
        for sectionID: DashboardCardSectionID,
        in configuration: DashboardCardConfiguration
    ) -> [DashboardCardPageID] {
        configuration.section(id: sectionID).pages.filter(\.isVisible).map(\.id)
    }

    private func ridingCard(_ id: DashboardCardSectionID) -> RidingDashboardCard {
        switch id {
        case .bikeLock: .bikeLock
        case .navigation: .navigation
        case .currentTrip: .currentTrip
        case .efficiency: .efficiency
        case .range: .range
        case .systemHealth: .systemHealth
        case .rideDynamics: .dynamics
        case .settings: .settings
        }
    }

    private func currentTripPage(_ id: DashboardCardPageID) -> CurrentTripDashboardPage? {
        switch id {
        case .currentTrip: .current
        case .rideStatistics: .statistics
        default: nil
        }
    }

    private func efficiencyPage(_ id: DashboardCardPageID) -> EfficiencyDashboardPage? {
        switch id {
        case .efficiencyLive: .live
        case .efficiencyTrend: .trend
        default: nil
        }
    }

    private func rangePage(_ id: DashboardCardPageID) -> RangeDashboardPage? {
        switch id {
        case .range: .range
        case .batteryTrip: .battery
        default: nil
        }
    }

    private func systemHealthPage(_ id: DashboardCardPageID) -> SystemHealthDashboardPage? {
        switch id {
        case .systemHealth: .health
        case .batteryCells: .cells
        case .thermal: .thermal
        default: nil
        }
    }

    private func dynamicsPage(_ id: DashboardCardPageID) -> RideDynamicsDashboardPage? {
        switch id {
        case .lean: .lean
        case .pitch: .pitch
        case .course: .course
        case .altitude: .altitude
        default: nil
        }
    }
}
