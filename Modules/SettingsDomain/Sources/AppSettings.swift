import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public private(set) var vin: String?
    public var speedSource: SpeedSource
    public var dashboardProgressBarMode: DashboardProgressBarMode
    public var dashboardBatteryIndicatorMode: DashboardBatteryIndicatorMode
    public var dashboardDeviceBatteryDisplayMode: DashboardDeviceBatteryDisplayMode
    public var dashboardTemperatureDisplayMode: DashboardTemperatureDisplayMode
    public var dashboardCardConfiguration: DashboardCardConfiguration
    public var rideNavigation: RideNavigationSettings
    public var liveActivities: LiveActivitySettings
    public var measurementSystem: MeasurementSystem
    public var defaultBatteryPackCapacity: BatteryPackCapacity
    public private(set) var batteryPackCapacitiesByVIN: [String: BatteryPackCapacity]
    public private(set) var powerModeNamesByVIN: [String: [Int: PowerModeName]]
    public private(set) var bikeLockSettingsByVIN: [String: BikeLockSettings]

    public var batteryPackCapacity: BatteryPackCapacity {
        defaultBatteryPackCapacity
    }

    public init(
        speedSource: SpeedSource = .motorcycle,
        dashboardProgressBarMode: DashboardProgressBarMode = .energy,
        dashboardBatteryIndicatorMode: DashboardBatteryIndicatorMode = .percentage,
        dashboardDeviceBatteryDisplayMode: DashboardDeviceBatteryDisplayMode = .iconAndText,
        dashboardTemperatureDisplayMode: DashboardTemperatureDisplayMode = .off,
        dashboardCardConfiguration: DashboardCardConfiguration = .init(),
        rideNavigation: RideNavigationSettings = .init(),
        liveActivities: LiveActivitySettings = .init(),
        measurementSystem: MeasurementSystem = .system,
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours,
        batteryPackCapacitiesByVIN: [String: BatteryPackCapacity] = [:],
        powerModeNamesByVIN: [String: [Int: PowerModeName]] = [:],
        bikeLockSettingsByVIN: [String: BikeLockSettings] = [:]
    ) {
        vin = nil
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode
        self.dashboardBatteryIndicatorMode = dashboardBatteryIndicatorMode
        self.dashboardDeviceBatteryDisplayMode = dashboardDeviceBatteryDisplayMode
        self.dashboardTemperatureDisplayMode = dashboardTemperatureDisplayMode
        self.dashboardCardConfiguration = dashboardCardConfiguration
        self.rideNavigation = rideNavigation
        self.liveActivities = liveActivities
        self.measurementSystem = measurementSystem
        defaultBatteryPackCapacity = batteryPackCapacity
        self.batteryPackCapacitiesByVIN = batteryPackCapacitiesByVIN
        self.powerModeNamesByVIN = Self.sanitizedPowerModeNames(powerModeNamesByVIN)
        self.bikeLockSettingsByVIN = bikeLockSettingsByVIN
    }

    @available(*, deprecated, message: "Use dashboardTemperatureDisplayMode")
    public init(
        speedSource: SpeedSource = .motorcycle,
        dashboardProgressBarMode: DashboardProgressBarMode = .energy,
        dashboardBatteryIndicatorMode: DashboardBatteryIndicatorMode = .percentage,
        dashboardDeviceBatteryDisplayMode: DashboardDeviceBatteryDisplayMode = .iconAndText,
        showsDashboardTemperatures: Bool,
        dashboardCardConfiguration: DashboardCardConfiguration = .init(),
        rideNavigation: RideNavigationSettings = .init(),
        liveActivities: LiveActivitySettings = .init(),
        measurementSystem: MeasurementSystem = .system,
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours,
        batteryPackCapacitiesByVIN: [String: BatteryPackCapacity] = [:],
        powerModeNamesByVIN: [String: [Int: PowerModeName]] = [:],
        bikeLockSettingsByVIN: [String: BikeLockSettings] = [:]
    ) {
        self.init(
            speedSource: speedSource,
            dashboardProgressBarMode: dashboardProgressBarMode,
            dashboardBatteryIndicatorMode: dashboardBatteryIndicatorMode,
            dashboardDeviceBatteryDisplayMode: dashboardDeviceBatteryDisplayMode,
            dashboardTemperatureDisplayMode: showsDashboardTemperatures ? .both : .off,
            dashboardCardConfiguration: dashboardCardConfiguration,
            rideNavigation: rideNavigation,
            liveActivities: liveActivities,
            measurementSystem: measurementSystem,
            batteryPackCapacity: batteryPackCapacity,
            batteryPackCapacitiesByVIN: batteryPackCapacitiesByVIN,
            powerModeNamesByVIN: powerModeNamesByVIN,
            bikeLockSettingsByVIN: bikeLockSettingsByVIN
        )
    }

    private enum CodingKeys: String, CodingKey {
        case vin
        case speedSource
        case dashboardProgressBarMode
        case dashboardBatteryIndicatorMode
        case dashboardDeviceBatteryDisplayMode
        case dashboardTemperatureDisplayMode
        case dashboardCardConfiguration
        case rideNavigation
        case liveActivities
        case measurementSystem
        case defaultBatteryPackCapacity
        case batteryPackCapacitiesByVIN
        case powerModeNamesByVIN
        case bikeLockSettingsByVIN
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case showsDashboardTemperatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vin = try container.decodeIfPresent(String.self, forKey: .vin)
        speedSource = try container.decodeIfPresent(SpeedSource.self, forKey: .speedSource) ?? .motorcycle
        dashboardProgressBarMode = try container.decodeIfPresent(
            DashboardProgressBarMode.self,
            forKey: .dashboardProgressBarMode
        ) ?? .energy
        dashboardBatteryIndicatorMode = try container.decodeIfPresent(
            DashboardBatteryIndicatorMode.self,
            forKey: .dashboardBatteryIndicatorMode
        ) ?? .percentage
        dashboardDeviceBatteryDisplayMode = try container.decodeIfPresent(
            DashboardDeviceBatteryDisplayMode.self,
            forKey: .dashboardDeviceBatteryDisplayMode
        ) ?? .iconAndText
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        dashboardTemperatureDisplayMode = try container.decodeIfPresent(
            DashboardTemperatureDisplayMode.self,
            forKey: .dashboardTemperatureDisplayMode
        ) ?? ((try legacyContainer.decodeIfPresent(
            Bool.self,
            forKey: .showsDashboardTemperatures
        ) ?? false) ? .both : .off)
        dashboardCardConfiguration = try container.decodeIfPresent(
            DashboardCardConfiguration.self,
            forKey: .dashboardCardConfiguration
        ) ?? .init()
        rideNavigation = try container.decodeIfPresent(
            RideNavigationSettings.self,
            forKey: .rideNavigation
        ) ?? .init()
        liveActivities = try container.decodeIfPresent(
            LiveActivitySettings.self, forKey: .liveActivities
        ) ?? .init()
        measurementSystem = try container.decodeIfPresent(MeasurementSystem.self, forKey: .measurementSystem) ?? .system
        defaultBatteryPackCapacity = try container.decodeIfPresent(
            BatteryPackCapacity.self,
            forKey: .defaultBatteryPackCapacity
        )
            ?? .sevenPointTwoKilowattHours
        batteryPackCapacitiesByVIN = try container.decodeIfPresent(
            [String: BatteryPackCapacity].self,
            forKey: .batteryPackCapacitiesByVIN
        ) ?? [:]
        powerModeNamesByVIN = Self.sanitizedPowerModeNames(try container.decodeIfPresent(
            [String: [Int: PowerModeName]].self,
            forKey: .powerModeNamesByVIN
        ) ?? [:])
        bikeLockSettingsByVIN = try container.decodeIfPresent(
            [String: BikeLockSettings].self,
            forKey: .bikeLockSettingsByVIN
        ) ?? [:]
    }

    public func batteryPackCapacity(forVIN vin: String?) -> BatteryPackCapacity {
        guard let vin else { return defaultBatteryPackCapacity }
        return batteryPackCapacitiesByVIN[vin] ?? defaultBatteryPackCapacity
    }

    public mutating func setBatteryPackCapacity(_ capacity: BatteryPackCapacity, forVIN vin: String) {
        batteryPackCapacitiesByVIN[vin] = capacity
    }

    public func powerModeNames(forVIN vin: String?) -> [Int: PowerModeName] {
        guard let vin else { return [:] }
        return Self.sanitizedPowerModeNames([vin: powerModeNamesByVIN[vin] ?? [:]])[vin] ?? [:]
    }

    public func powerModeName(forVIN vin: String?, mapIndex: Int) -> PowerModeName? {
        powerModeNames(forVIN: vin)[mapIndex]
    }

    public mutating func setPowerModeName(
        _ name: PowerModeName,
        forVIN vin: String,
        mapIndex: Int
    ) throws {
        guard Self.powerModeIndices.contains(mapIndex) else {
            throw PowerModeNameAssignmentError.invalidMapIndex
        }
        var names = powerModeNamesByVIN[vin] ?? [:]
        guard !names.contains(where: { index, existingName in
            index != mapIndex && name.matchesIgnoringCase(existingName)
        }) else {
            throw PowerModeNameAssignmentError.duplicate
        }
        names[mapIndex] = name
        powerModeNamesByVIN[vin] = names
    }

    public mutating func clearPowerModeName(forVIN vin: String, mapIndex: Int) {
        guard Self.powerModeIndices.contains(mapIndex) else { return }
        guard var names = powerModeNamesByVIN[vin] else { return }
        names[mapIndex] = nil
        if names.isEmpty {
            powerModeNamesByVIN[vin] = nil
        } else {
            powerModeNamesByVIN[vin] = names
        }
    }

    public func bikeLockSettings(forVIN vin: String?) -> BikeLockSettings {
        guard let vin else { return .init() }
        return bikeLockSettingsByVIN[vin] ?? .init()
    }

    public mutating func setBikeLockSettings(_ settings: BikeLockSettings, forVIN vin: String) {
        if settings.securityMode == .notConfigured {
            bikeLockSettingsByVIN[vin] = nil
        } else {
            bikeLockSettingsByVIN[vin] = settings
        }
    }

    @available(*, deprecated, message: "Use dashboardTemperatureDisplayMode")
    public var showsDashboardTemperatures: Bool {
        get { dashboardTemperatureDisplayMode.isEnabled }
        set { dashboardTemperatureDisplayMode = newValue ? .both : .off }
    }

    private static let powerModeIndices = 0 ... 4

    private static func sanitizedPowerModeNames(
        _ namesByVIN: [String: [Int: PowerModeName]]
    ) -> [String: [Int: PowerModeName]] {
        namesByVIN.reduce(into: [:]) { result, entry in
            var sanitized: [Int: PowerModeName] = [:]
            for (mapIndex, name) in entry.value.sorted(by: { $0.key < $1.key })
                where powerModeIndices.contains(mapIndex)
                    && !sanitized.values.contains(where: { name.matchesIgnoringCase($0) }) {
                sanitized[mapIndex] = name
            }
            if !sanitized.isEmpty {
                result[entry.key] = sanitized
            }
        }
    }
}

public extension AppSettings {
    func scoped(toVIN vin: String) -> AppSettings {
        var settings = self
        settings.vin = vin
        settings.batteryPackCapacitiesByVIN = batteryPackCapacitiesByVIN.filter { $0.key == vin }
        settings.powerModeNamesByVIN = powerModeNamesByVIN.filter { $0.key == vin }
        settings.bikeLockSettingsByVIN = bikeLockSettingsByVIN.filter { $0.key == vin }
        return settings
    }
}
