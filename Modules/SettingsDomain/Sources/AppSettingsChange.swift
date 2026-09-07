public enum AppSettingsChange: Equatable, Sendable {
    case speedSource(SpeedSource)
    case dashboardProgressBarMode(DashboardProgressBarMode)
    case dashboardBatteryIndicatorMode(DashboardBatteryIndicatorMode)
    case dashboardDeviceBatteryDisplayMode(DashboardDeviceBatteryDisplayMode)
    case dashboardTemperatureDisplayMode(DashboardTemperatureDisplayMode)
    case measurementSystem(MeasurementSystem)
    case batteryPackCapacity(BatteryPackCapacity)
    case powerModeName(mapIndex: Int, name: PowerModeName?)
    case bikeLockSecurity(BikeLockSecurityMode)
    case dashboard(Dashboard)
    case navigation(Navigation)
    case liveActivities(LiveActivities)

    public enum Dashboard: Equatable, Sendable {
        case sectionOrder([DashboardCardSectionID])
        case sectionVisibility(id: DashboardCardSectionID, isVisible: Bool)
        case pageOrder(sectionID: DashboardCardSectionID, ids: [DashboardCardPageID])
        case pageVisibility(sectionID: DashboardCardSectionID, id: DashboardCardPageID, isVisible: Bool)
    }

    public enum Navigation: Equatable, Sendable {
        case avoidsTolls(Bool)
        case avoidsHighways(Bool)
        case preferredMapStyle(RideNavigationMapStylePreference)
        case mapOrientation(RideNavigationMapOrientationPreference)
        case miniMapPosition(MiniMapPosition)
        case miniMapScale(MiniMapScale)
        case miniMapLayoutOrientation(MiniMapLayoutOrientation)
        case showsGuidanceInFocus(Bool)
        case showsCompassRing(Bool)
        case showsRoadsInFocus(Bool)
        case lineColor(group: RideNavigationLineGroup, color: RideNavigationLineColor)
        case lineThickness(group: RideNavigationLineGroup, thickness: RideNavigationLineThickness)
    }

    public enum LiveActivities: Equatable, Sendable {
        case isEnabled(Bool)
        case showsRiding(Bool)
        case showsCharging(Bool)
        case ridingDetailLevel(LiveActivitySettings.DetailLevel)
        case chargingDetailLevel(LiveActivitySettings.DetailLevel)
    }

    public func applying(to settings: AppSettings) throws -> AppSettings {
        guard let vin = settings.vin else { throw AppSettingsUpdateError.vehicleUnavailable }
        var updated = settings
        switch self {
        case let .speedSource(value): updated.speedSource = value
        case let .dashboardProgressBarMode(value): updated.dashboardProgressBarMode = value
        case let .dashboardBatteryIndicatorMode(value): updated.dashboardBatteryIndicatorMode = value
        case let .dashboardDeviceBatteryDisplayMode(value): updated.dashboardDeviceBatteryDisplayMode = value
        case let .dashboardTemperatureDisplayMode(value): updated.dashboardTemperatureDisplayMode = value
        case let .measurementSystem(value): updated.measurementSystem = value
        case let .batteryPackCapacity(value): updated.setBatteryPackCapacity(value, forVIN: vin)
        case let .powerModeName(mapIndex, name):
            try applyPowerModeName(name, mapIndex: mapIndex, vin: vin, to: &updated)
        case let .bikeLockSecurity(mode):
            updated.setBikeLockSettings(.init(securityMode: mode), forVIN: vin)
            if mode.requiresPIN { updated.dashboardCardConfiguration.setSectionVisibility(true, id: .bikeLock) }
        case let .dashboard(change): try change.apply(to: &updated.dashboardCardConfiguration)
        case let .navigation(change): change.apply(to: &updated.rideNavigation)
        case let .liveActivities(change): change.apply(to: &updated.liveActivities)
        }
        return updated
    }
}

private extension AppSettingsChange {
    func applyPowerModeName(_ name: PowerModeName?, mapIndex: Int, vin: String, to updated: inout AppSettings) throws {
            guard (0 ... 4).contains(mapIndex) else { throw AppSettingsUpdateError.invalidChange }
            if let name {
                do {
                    try updated.setPowerModeName(name, forVIN: vin, mapIndex: mapIndex)
                } catch PowerModeNameAssignmentError.duplicate {
                    throw AppSettingsUpdateError.duplicatePowerModeName
                } catch {
                    throw AppSettingsUpdateError.invalidChange
                }
            } else {
                updated.clearPowerModeName(forVIN: vin, mapIndex: mapIndex)
            }
    }
}

private extension AppSettingsChange.Dashboard {
    func apply(to configuration: inout DashboardCardConfiguration) throws {
        switch self {
        case var .sectionOrder(ids):
            if !ids.contains(.bikeLock),
               let index = configuration.sections.firstIndex(where: { $0.id == .bikeLock }) {
                ids.insert(.bikeLock, at: min(index, ids.endIndex))
            }
            configuration.setSectionOrder(ids)
        case let .sectionVisibility(id, isVisible):
            guard configuration.section(id: id).isVisible != isVisible else { return }
            guard id != .bikeLock, id != .settings else { throw AppSettingsUpdateError.invalidChange }
            configuration.setSectionVisibility(isVisible, id: id)
        case let .pageOrder(sectionID, ids): configuration.setPageOrder(ids, sectionID: sectionID)
        case let .pageVisibility(sectionID, id, isVisible):
            guard id.sectionID == sectionID,
                  let page = configuration.section(id: sectionID).pages.first(where: { $0.id == id }) else {
                throw AppSettingsUpdateError.invalidChange
            }
            guard page.isVisible != isVisible else { return }
            guard configuration.setPageVisibility(isVisible, id: id, sectionID: sectionID) else {
                throw AppSettingsUpdateError.invalidChange
            }
        }
    }
}

private extension AppSettingsChange.Navigation {
    func apply(to settings: inout RideNavigationSettings) {
        switch self {
        case let .avoidsTolls(value): settings.avoidsTolls = value
        case let .avoidsHighways(value): settings.avoidsHighways = value
        case let .preferredMapStyle(value): settings.preferredMapStyle = value
        case let .mapOrientation(value): settings.mapOrientation = value
        case let .miniMapPosition(value): settings.miniMapPosition = value
        case let .miniMapScale(value): settings.miniMapScale = value
        case let .miniMapLayoutOrientation(value): settings.miniMapLayoutOrientation = value
        case let .showsGuidanceInFocus(value): settings.showsGuidanceInFocus = value
        case let .showsCompassRing(value): settings.showsCompassRing = value
        case let .showsRoadsInFocus(value): settings.showsRoadsInFocus = value
        case let .lineColor(group, color): settings.lineAppearances[group].color = color
        case let .lineThickness(group, thickness): settings.lineAppearances[group].thickness = thickness
        }
    }
}

private extension AppSettingsChange.LiveActivities {
    func apply(to settings: inout LiveActivitySettings) {
        switch self {
        case let .isEnabled(value): settings.isEnabled = value
        case let .showsRiding(value): settings.showsRiding = value
        case let .showsCharging(value): settings.showsCharging = value
        case let .ridingDetailLevel(value): settings.ridingDetailLevel = value
        case let .chargingDetailLevel(value): settings.chargingDetailLevel = value
        }
    }
}
