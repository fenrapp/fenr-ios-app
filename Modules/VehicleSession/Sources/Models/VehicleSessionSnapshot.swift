import BikeDomain
import SettingsDomain

public struct VehicleSessionSnapshot: Equatable, Sendable {
    public let telemetry: BikeTelemetry
    public let connection: BikeConnection
    public let settings: AppSettings
    public let profile: BikeProfile?
    public let resolvedSpeedKilometersPerHour: Double?
    public let speedSource: SpeedSource
    public let isGPSAvailable: Bool
    public let batteryHealth: BikeBatteryHealth
    public let batteryHealthMonitoringState: VehicleBatteryHealthMonitoringState
    public let motion: VehicleMotionSnapshot
    public let hasReceivedSettings: Bool
    public let hasReceivedProfile: Bool

    public init(
        telemetry: BikeTelemetry = .init(),
        connection: BikeConnection = .init(),
        settings: AppSettings = .init(),
        profile: BikeProfile? = nil,
        resolvedSpeedKilometersPerHour: Double? = nil,
        speedSource: SpeedSource = .motorcycle,
        isGPSAvailable: Bool = false,
        batteryHealth: BikeBatteryHealth = .init(),
        batteryHealthMonitoringState: VehicleBatteryHealthMonitoringState = .inactive,
        motion: VehicleMotionSnapshot = .init(),
        hasReceivedSettings: Bool = false,
        hasReceivedProfile: Bool = false
    ) {
        self.telemetry = telemetry
        self.connection = connection
        self.settings = settings
        self.profile = profile
        self.resolvedSpeedKilometersPerHour = resolvedSpeedKilometersPerHour
        self.speedSource = speedSource
        self.isGPSAvailable = isGPSAvailable
        self.batteryHealth = batteryHealth
        self.batteryHealthMonitoringState = batteryHealthMonitoringState
        self.motion = motion
        self.hasReceivedSettings = hasReceivedSettings
        self.hasReceivedProfile = hasReceivedProfile
    }
}
