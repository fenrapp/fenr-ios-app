import Foundation
import SwiftData

@Model
final class RideTripRecord {
    @Attribute(.unique) var id: UUID
    var applicationSessionID: UUID
    var startedAt: Date
    var updatedAt: Date
    var endedAt: Date?
    var startingOdometerKilometers: Double?
    var distanceKilometers: Double
    var elapsedSeconds: TimeInterval
    var averageSpeedKilometersPerHour: Double
    var maximumSpeedKilometersPerHour: Double
    var accumulatedSpeedKilometersPerHourSeconds: Double = 0
    var speedSampleDurationSeconds: TimeInterval = 0
    var lastSpeedKilometersPerHour: Double?
    var pausedAt: Date?
    var accumulatedPausedSeconds: TimeInterval = 0
    var isAwaitingOdometerRebase = false

    init(
        id: UUID,
        applicationSessionID: UUID,
        startedAt: Date,
        updatedAt: Date,
        endedAt: Date?,
        startingOdometerKilometers: Double?,
        distanceKilometers: Double,
        elapsedSeconds: TimeInterval,
        averageSpeedKilometersPerHour: Double,
        maximumSpeedKilometersPerHour: Double,
        accumulatedSpeedKilometersPerHourSeconds: Double,
        speedSampleDurationSeconds: TimeInterval,
        lastSpeedKilometersPerHour: Double?,
        pausedAt: Date?,
        accumulatedPausedSeconds: TimeInterval,
        isAwaitingOdometerRebase: Bool
    ) {
        self.id = id
        self.applicationSessionID = applicationSessionID
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.endedAt = endedAt
        self.startingOdometerKilometers = startingOdometerKilometers
        self.distanceKilometers = distanceKilometers
        self.elapsedSeconds = elapsedSeconds
        self.averageSpeedKilometersPerHour = averageSpeedKilometersPerHour
        self.maximumSpeedKilometersPerHour = maximumSpeedKilometersPerHour
        self.accumulatedSpeedKilometersPerHourSeconds = accumulatedSpeedKilometersPerHourSeconds
        self.speedSampleDurationSeconds = speedSampleDurationSeconds
        self.lastSpeedKilometersPerHour = lastSpeedKilometersPerHour
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = accumulatedPausedSeconds
        self.isAwaitingOdometerRebase = isAwaitingOdometerRebase
    }
}
