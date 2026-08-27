import Foundation
import SwiftData

@Model
final class RideTripRecord {
    @Attribute(.unique) var id: UUID
    var vehicleIdentityKind: String
    var vehicleIdentityValue: String
    var applicationSessionID: UUID
    var startedAt: Date
    var updatedAt: Date
    var endedAt: Date?
    var startingOdometerKilometers: Double?
    var distanceKilometers: Double
    var elapsedSeconds: TimeInterval
    var averageSpeedKilometersPerHour: Double
    var maximumSpeedKilometersPerHour: Double
    var accumulatedSpeedKilometersPerHourSeconds: Double
    var speedSampleDurationSeconds: TimeInterval
    var lastSpeedKilometersPerHour: Double?
    var pausedAt: Date?
    var accumulatedPausedSeconds: TimeInterval
    var isAwaitingOdometerRebase: Bool
    var consumedEnergyWattHours: Double
    var recoveredEnergyWattHours: Double
    var electricalObservedSeconds: TimeInterval
    var electricalExpectedSeconds: TimeInterval
    var maximumDischargePowerWatts: Double
    var maximumRegenerationPowerWatts: Double
    var lastElectricalPowerWatts: Double?
    var lastElectricalSampleAt: Date?
    var isAwaitingElectricalRebase: Bool

    init(
        id: UUID,
        vehicleIdentityKind: String,
        vehicleIdentityValue: String,
        applicationSessionID: UUID,
        startedAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.vehicleIdentityKind = vehicleIdentityKind
        self.vehicleIdentityValue = vehicleIdentityValue
        self.applicationSessionID = applicationSessionID
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        endedAt = nil
        startingOdometerKilometers = nil
        distanceKilometers = .zero
        elapsedSeconds = .zero
        averageSpeedKilometersPerHour = .zero
        maximumSpeedKilometersPerHour = .zero
        accumulatedSpeedKilometersPerHourSeconds = .zero
        speedSampleDurationSeconds = .zero
        lastSpeedKilometersPerHour = nil
        pausedAt = nil
        accumulatedPausedSeconds = .zero
        isAwaitingOdometerRebase = false
        consumedEnergyWattHours = .zero
        recoveredEnergyWattHours = .zero
        electricalObservedSeconds = .zero
        electricalExpectedSeconds = .zero
        maximumDischargePowerWatts = .zero
        maximumRegenerationPowerWatts = .zero
        lastElectricalPowerWatts = nil
        lastElectricalSampleAt = nil
        isAwaitingElectricalRebase = true
    }
}
