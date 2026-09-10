import Foundation

public struct BikeTelemetry: Equatable, Sendable {
    public var vin: String
    public var mode: BikeMode
    public var speed: BikeSpeed
    public var motorRPM: MotorRPM
    public var odometer: BikeOdometer
    public var inverterTemperatureRawValues: [UInt16]
    public var inverterTemperaturesCelsius: [Double?]
    public var statusFlags: BikeStatusFlags
    public var rawStatusFlags: BikeRawStatusFlags
    public var powerModeConfigurations: [Int: BikePowerModeConfiguration]
    public var detectedPowerTier: BikeDetectedPowerTier
    public var powerTelemetry: BikePowerTelemetry
    public var batteryTelemetry: BikeBatteryTelemetry
    public var lastUpdated: Date?

    public var batteryLevel: BatteryLevel {
        get { batteryTelemetry.stateOfCharge }
        set { batteryTelemetry.stateOfCharge = newValue }
    }

    public var healthLevel: HealthLevel {
        get { batteryTelemetry.stateOfHealth }
        set { batteryTelemetry.stateOfHealth = newValue }
    }

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
        powerModeConfigurations: [Int: BikePowerModeConfiguration] = [:],
        detectedPowerTier: BikeDetectedPowerTier = .standardBaseline,
        powerTelemetry: BikePowerTelemetry = .init(),
        batteryTelemetry: BikeBatteryTelemetry = .init(),
        lastUpdated: Date? = nil
    ) {
        self.vin = vin
        self.mode = mode
        self.speed = speed
        self.motorRPM = motorRPM
        self.odometer = odometer
        self.inverterTemperatureRawValues = inverterTemperatureRawValues
        self.inverterTemperaturesCelsius = inverterTemperaturesCelsius
        self.statusFlags = statusFlags
        self.rawStatusFlags = rawStatusFlags
        self.powerModeConfigurations = powerModeConfigurations
        self.detectedPowerTier = detectedPowerTier
        self.powerTelemetry = powerTelemetry
        var resolvedBatteryTelemetry = batteryTelemetry
        if resolvedBatteryTelemetry.stateOfCharge == .unknown {
            resolvedBatteryTelemetry.stateOfCharge = batteryLevel
        }
        if resolvedBatteryTelemetry.stateOfHealth == .unknown {
            resolvedBatteryTelemetry.stateOfHealth = healthLevel
        }
        self.batteryTelemetry = resolvedBatteryTelemetry
        self.lastUpdated = lastUpdated
    }

    public var activePowerModeConfiguration: BikePowerModeConfiguration? {
        guard let index = mode.powerModeConfigurationIndex else { return nil }
        return powerModeConfigurations[index]
    }

    public var runState: BikeRunState {
        guard statusFlags.crawlState != .unknown else { return .unknown }
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
