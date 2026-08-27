import Foundation
import RideSessionDomain
import SettingsDomain
import VehicleSession

public struct RideElectricalPowerSample: Equatable, Identifiable, Sendable {
    public let id: Date
    public let date: Date
    public let powerWatts: Double

    public init(date: Date, powerWatts: Double) {
        id = date
        self.date = date
        self.powerWatts = powerWatts
    }
}

public struct RideSessionSnapshot: Equatable, Sendable {
    public let trip: RideTrip?
    public let vehicleIdentity: RideVehicleIdentity
    public let resolvedSpeedKilometersPerHour: Double?
    public let speedSource: SpeedSource
    public let measurementSystem: MeasurementSystem
    public let isGPSAvailable: Bool
    public let livePowerSamples: [RideElectricalPowerSample]
    public let historyRevision: Int
    public let batteryStateOfChargePercent: Int?
    public let batteryCapacityWattHours: Double
    public let motion: VehicleMotionSnapshot

    public init(
        trip: RideTrip? = nil,
        vehicleIdentity: RideVehicleIdentity,
        resolvedSpeedKilometersPerHour: Double? = nil,
        speedSource: SpeedSource = .motorcycle,
        measurementSystem: MeasurementSystem = .metric,
        isGPSAvailable: Bool = false,
        livePowerSamples: [RideElectricalPowerSample] = [],
        historyRevision: Int = .zero,
        batteryStateOfChargePercent: Int? = nil,
        batteryCapacityWattHours: Double = .zero,
        motion: VehicleMotionSnapshot = .init()
    ) {
        self.trip = trip
        self.vehicleIdentity = vehicleIdentity
        self.resolvedSpeedKilometersPerHour = resolvedSpeedKilometersPerHour
        self.speedSource = speedSource
        self.measurementSystem = measurementSystem
        self.isGPSAvailable = isGPSAvailable
        self.livePowerSamples = livePowerSamples
        self.historyRevision = historyRevision
        self.batteryStateOfChargePercent = batteryStateOfChargePercent
        self.batteryCapacityWattHours = batteryCapacityWattHours
        self.motion = motion
    }
}
