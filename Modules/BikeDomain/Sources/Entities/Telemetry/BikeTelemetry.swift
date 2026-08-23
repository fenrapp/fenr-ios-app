import Foundation

public struct BikeTelemetry: Equatable, Sendable {
    public var vin: String
    public var batteryLevel: BatteryLevel
    public var healthLevel: HealthLevel
    public var mode: BikeMode
    public var speed: BikeSpeed
    public var motorRPM: MotorRPM
    public var odometer: BikeOdometer
    public var inverterTemperatureRawValues: [UInt16]
    public var inverterTemperaturesCelsius: [Double?]
    public var statusFlags: BikeStatusFlags
    public var rawStatusFlags: BikeRawStatusFlags
    public var lastUpdated: Date?

    public init(
        vin: String = "",
        batteryLevel: BatteryLevel = .unknown,
        healthLevel: HealthLevel = .unknown,
        mode: BikeMode = .unknown,
        speed: BikeSpeed = .unknown,
        motorRPM: MotorRPM = .unknown,
        odometer: BikeOdometer = .unknown,
        inverterTemperatureRawValues: [UInt16] = [],
        inverterTemperaturesCelsius: [Double?] = [],
        statusFlags: BikeStatusFlags = .unknown,
        rawStatusFlags: BikeRawStatusFlags = .unknown,
        lastUpdated: Date? = nil
    ) {
        self.vin = vin
        self.batteryLevel = batteryLevel
        self.healthLevel = healthLevel
        self.mode = mode
        self.speed = speed
        self.motorRPM = motorRPM
        self.odometer = odometer
        self.inverterTemperatureRawValues = inverterTemperatureRawValues
        self.inverterTemperaturesCelsius = inverterTemperaturesCelsius
        self.statusFlags = statusFlags
        self.rawStatusFlags = rawStatusFlags
        self.lastUpdated = lastUpdated
    }

    public var runState: BikeRunState {
        guard statusFlags != .unknown else { return .unknown }
        switch statusFlags.crawlState {
        case .forward:
            return .crawlForward
        case .reverse:
            return .crawlReverse
        case .inactive, .unknown:
            break
        }
        if statusFlags.isCharging { return .charging }
        if statusFlags.isInGear { return .on }
        if statusFlags.isOn { return .neutral }
        return .off
    }
}
