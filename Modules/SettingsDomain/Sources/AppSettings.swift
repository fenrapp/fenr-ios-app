import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var speedSource: SpeedSource
    public var measurementSystem: MeasurementSystem
    public var defaultBatteryPackCapacity: BatteryPackCapacity
    public var batteryPackCapacitiesByVIN: [String: BatteryPackCapacity]

    public var batteryPackCapacity: BatteryPackCapacity {
        defaultBatteryPackCapacity
    }

    public init(
        speedSource: SpeedSource = .motorcycle,
        measurementSystem: MeasurementSystem = .system,
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours,
        batteryPackCapacitiesByVIN: [String: BatteryPackCapacity] = [:]
    ) {
        self.speedSource = speedSource
        self.measurementSystem = measurementSystem
        defaultBatteryPackCapacity = batteryPackCapacity
        self.batteryPackCapacitiesByVIN = batteryPackCapacitiesByVIN
    }

    private enum CodingKeys: String, CodingKey {
        case speedSource
        case measurementSystem
        case defaultBatteryPackCapacity
        case batteryPackCapacitiesByVIN
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speedSource = try container.decodeIfPresent(SpeedSource.self, forKey: .speedSource) ?? .motorcycle
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
    }

    public func batteryPackCapacity(forVIN vin: String?) -> BatteryPackCapacity {
        guard let vin else { return defaultBatteryPackCapacity }
        return batteryPackCapacitiesByVIN[vin] ?? defaultBatteryPackCapacity
    }

    public mutating func setBatteryPackCapacity(_ capacity: BatteryPackCapacity, forVIN vin: String) {
        batteryPackCapacitiesByVIN[vin] = capacity
    }
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
