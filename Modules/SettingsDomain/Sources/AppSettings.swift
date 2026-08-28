import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var speedSource: SpeedSource
    public var dashboardProgressBarMode: DashboardProgressBarMode
    public var dashboardBatteryIndicatorMode: DashboardBatteryIndicatorMode
    public var showsDashboardTemperatures: Bool
    public var dashboardCardConfiguration: DashboardCardConfiguration
    public var measurementSystem: MeasurementSystem
    public var defaultBatteryPackCapacity: BatteryPackCapacity
    public var batteryPackCapacitiesByVIN: [String: BatteryPackCapacity]
    public var powerModeNamesByVIN: [String: [Int: PowerModeName]]

    public var batteryPackCapacity: BatteryPackCapacity {
        defaultBatteryPackCapacity
    }

    public init(
        speedSource: SpeedSource = .motorcycle,
        dashboardProgressBarMode: DashboardProgressBarMode = .energy,
        dashboardBatteryIndicatorMode: DashboardBatteryIndicatorMode = .percentage,
        showsDashboardTemperatures: Bool = false,
        dashboardCardConfiguration: DashboardCardConfiguration = .init(),
        measurementSystem: MeasurementSystem = .system,
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours,
        batteryPackCapacitiesByVIN: [String: BatteryPackCapacity] = [:],
        powerModeNamesByVIN: [String: [Int: PowerModeName]] = [:]
    ) {
        self.speedSource = speedSource
        self.dashboardProgressBarMode = dashboardProgressBarMode
        self.dashboardBatteryIndicatorMode = dashboardBatteryIndicatorMode
        self.showsDashboardTemperatures = showsDashboardTemperatures
        self.dashboardCardConfiguration = dashboardCardConfiguration
        self.measurementSystem = measurementSystem
        defaultBatteryPackCapacity = batteryPackCapacity
        self.batteryPackCapacitiesByVIN = batteryPackCapacitiesByVIN
        self.powerModeNamesByVIN = Self.sanitizedPowerModeNames(powerModeNamesByVIN)
    }

    private enum CodingKeys: String, CodingKey {
        case speedSource
        case dashboardProgressBarMode
        case dashboardBatteryIndicatorMode
        case showsDashboardTemperatures
        case dashboardCardConfiguration
        case measurementSystem
        case defaultBatteryPackCapacity
        case batteryPackCapacitiesByVIN
        case powerModeNamesByVIN
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speedSource = try container.decodeIfPresent(SpeedSource.self, forKey: .speedSource) ?? .motorcycle
        dashboardProgressBarMode = try container.decodeIfPresent(
            DashboardProgressBarMode.self,
            forKey: .dashboardProgressBarMode
        ) ?? .energy
        dashboardBatteryIndicatorMode = try container.decodeIfPresent(
            DashboardBatteryIndicatorMode.self,
            forKey: .dashboardBatteryIndicatorMode
        ) ?? .percentage
        showsDashboardTemperatures = try container.decodeIfPresent(
            Bool.self,
            forKey: .showsDashboardTemperatures
        ) ?? false
        dashboardCardConfiguration = try container.decodeIfPresent(
            DashboardCardConfiguration.self,
            forKey: .dashboardCardConfiguration
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

public enum DashboardProgressBarMode: String, Codable, CaseIterable, Sendable {
    case energy
    case speed
    case hidden
}

public enum DashboardBatteryIndicatorMode: String, Codable, CaseIterable, Sendable {
    case percentage
    case estimatedRange
}

public enum SpeedSource: String, Codable, CaseIterable, Sendable {
    case motorcycle
    case gps
    case hybrid

    public var usesDeviceLocation: Bool {
        self != .motorcycle
    }
}

public enum MeasurementSystem: String, Codable, CaseIterable, Sendable {
    case system
    case metric
    case imperial

    public func resolved(for locale: Locale = .autoupdatingCurrent) -> Locale.MeasurementSystem {
        switch self {
        case .system: locale.measurementSystem
        case .metric: .metric
        case .imperial: .us
        }
    }
}

public enum BatteryPackCapacity: String, Codable, CaseIterable, Sendable {
    case sixPointEightKilowattHours
    case sevenPointTwoKilowattHours

    public var wattHours: Double {
        switch self {
        case .sixPointEightKilowattHours: 6_800
        case .sevenPointTwoKilowattHours: 7_200
        }
    }

    public var displayName: String {
        switch self {
        case .sixPointEightKilowattHours: "6.8 kWh"
        case .sevenPointTwoKilowattHours: "7.2 kWh"
        }
    }
}
