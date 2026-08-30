import Foundation
import RideSessionDomain
import SwiftData

@ModelActor
actor RideTripStore {
    func prepare(
        context: BikeSessionContext,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) -> RideTrip? {
        do {
            try purgeExpiredTemporaryRecords(applicationSessionID: context.applicationSessionID)
            var restoredTrip: RideTrip?
            for record in try fetchActiveRecords() {
                guard let trip = mapper.mapToDomain(record) else {
                    try deleteTripRecordAndEnergyBuckets(record)
                    continue
                }
                if trip.applicationSessionID == context.applicationSessionID,
                   trip.vehicleIdentity == context.vehicleIdentity,
                   restoredTrip == nil {
                    let buckets = try fetchEnergyBuckets(
                        tripID: trip.id,
                        mapper: energyBucketMapper
                    )
                    let restored = trip
                        .restoringEnergyBuckets(buckets)
                        .rebasingElectrical()
                    restoredTrip = restored
                    mapper.update(record, from: restored)
                } else if trip.confirmedVIN != nil {
                    mapper.update(record, from: trip.completed(at: trip.updatedAt))
                } else {
                    try deleteTripRecordAndEnergyBuckets(record)
                }
            }
            try modelContext.save()
            return restoredTrip
        } catch {
            handlePersistenceError(error)
            return nil
        }
    }

    func saveActiveTrip(
        _ trip: RideTrip,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) -> Bool {
        guard trip.endedAt == nil else { return false }
        do {
            try upsert(trip, mapper: mapper)
            try syncEnergyBuckets(trip, mapper: energyBucketMapper)
            try modelContext.save()
            return true
        } catch {
            handlePersistenceError(error)
            return false
        }
    }

    func completeTrip(
        _ trip: RideTrip,
        at date: Date,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) -> Bool {
        do {
            let completed = trip.completed(at: date)
            try upsert(completed, mapper: mapper)
            try syncEnergyBuckets(completed, mapper: energyBucketMapper)
            try modelContext.save()
            return true
        } catch {
            handlePersistenceError(error)
            return false
        }
    }

    func resetTrip(
        completing trip: RideTrip,
        starting replacement: RideTrip?,
        at date: Date,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) -> Bool {
        do {
            let completed = trip.completed(at: date)
            try upsert(completed, mapper: mapper)
            try syncEnergyBuckets(completed, mapper: energyBucketMapper)
            if let replacement {
                try upsert(replacement, mapper: mapper)
                try syncEnergyBuckets(replacement, mapper: energyBucketMapper)
            }
            try modelContext.save()
            return true
        } catch {
            handlePersistenceError(error)
            return false
        }
    }
}
