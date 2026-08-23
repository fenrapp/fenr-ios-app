import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var speedSource: SpeedSource
    public var measurementSystem: MeasurementSystem
    public var batteryPackCapacity: BatteryPackCapacity

    public init(
        speedSource: SpeedSource = .motorcycle,
        measurementSystem: MeasurementSystem = .system,
        batteryPackCapacity: BatteryPackCapacity = .sevenPointTwoKilowattHours
    ) {
        self.speedSource = speedSource
        self.measurementSystem = measurementSystem
        self.batteryPackCapacity = batteryPackCapacity
    }

    private enum CodingKeys: String, CodingKey {
        case speedSource
        case measurementSystem
        case batteryPackCapacity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speedSource = try container.decodeIfPresent(SpeedSource.self, forKey: .speedSource) ?? .motorcycle
        measurementSystem = try container.decodeIfPresent(MeasurementSystem.self, forKey: .measurementSystem) ?? .system
        batteryPackCapacity = try container.decodeIfPresent(BatteryPackCapacity.self, forKey: .batteryPackCapacity)
            ?? .sevenPointTwoKilowattHours
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
