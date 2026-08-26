import RideSessionDomain

public struct RideTripRecordMapper {
    public init() {}

    func makeRecord(from trip: RideTrip) -> RideTripRecord {
        let record = RideTripRecord(
            id: trip.id,
            applicationSessionID: trip.applicationSessionID,
            startedAt: trip.startedAt,
            updatedAt: trip.updatedAt,
            endedAt: trip.endedAt,
            startingOdometerKilometers: trip.startingOdometerKilometers,
            distanceKilometers: trip.distanceKilometers,
            elapsedSeconds: trip.elapsedSeconds,
            averageSpeedKilometersPerHour: trip.averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: trip.maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: trip.accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: trip.speedSampleDurationSeconds,
            lastSpeedKilometersPerHour: trip.lastSpeedKilometersPerHour,
            pausedAt: trip.pausedAt,
            accumulatedPausedSeconds: trip.accumulatedPausedSeconds,
            isAwaitingOdometerRebase: trip.isAwaitingOdometerRebase
        )
        return record
    }

    func update(_ record: RideTripRecord, from trip: RideTrip) {
        record.applicationSessionID = trip.applicationSessionID
        record.startedAt = trip.startedAt
        record.updatedAt = trip.updatedAt
        record.endedAt = trip.endedAt
        record.startingOdometerKilometers = trip.startingOdometerKilometers
        record.distanceKilometers = trip.distanceKilometers
        record.elapsedSeconds = trip.elapsedSeconds
        record.averageSpeedKilometersPerHour = trip.averageSpeedKilometersPerHour
        record.maximumSpeedKilometersPerHour = trip.maximumSpeedKilometersPerHour
        record.accumulatedSpeedKilometersPerHourSeconds = trip.accumulatedSpeedKilometersPerHourSeconds
        record.speedSampleDurationSeconds = trip.speedSampleDurationSeconds
        record.lastSpeedKilometersPerHour = trip.lastSpeedKilometersPerHour
        record.pausedAt = trip.pausedAt
        record.accumulatedPausedSeconds = trip.accumulatedPausedSeconds
        record.isAwaitingOdometerRebase = trip.isAwaitingOdometerRebase
    }

    func mapToDomain(_ record: RideTripRecord) -> RideTrip {
        RideTrip(
            id: record.id,
            applicationSessionID: record.applicationSessionID,
            startedAt: record.startedAt,
            updatedAt: record.updatedAt,
            endedAt: record.endedAt,
            startingOdometerKilometers: record.startingOdometerKilometers,
            distanceKilometers: record.distanceKilometers,
            elapsedSeconds: record.elapsedSeconds,
            averageSpeedKilometersPerHour: record.averageSpeedKilometersPerHour,
            maximumSpeedKilometersPerHour: record.maximumSpeedKilometersPerHour,
            accumulatedSpeedKilometersPerHourSeconds: record.accumulatedSpeedKilometersPerHourSeconds,
            speedSampleDurationSeconds: record.speedSampleDurationSeconds,
            lastSpeedKilometersPerHour: record.lastSpeedKilometersPerHour,
            pausedAt: record.pausedAt,
            accumulatedPausedSeconds: record.accumulatedPausedSeconds,
            isAwaitingOdometerRebase: record.isAwaitingOdometerRebase
        )
    }
}
