import Foundation
import OSLog
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
                    modelContext.delete(record)
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
                    modelContext.delete(record)
                }
            }
            try modelContext.save()
            try trimAllConfirmedHistories()
            return restoredTrip
        } catch {
            report(error)
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
            report(error)
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
            if let vin = completed.confirmedVIN {
                try trimHistory(vin: vin)
            }
            return true
        } catch {
            report(error)
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
            if let vin = completed.confirmedVIN {
                try trimHistory(vin: vin)
            }
            return true
        } catch {
            report(error)
            return false
        }
    }

    func loadCompletedTrips(
        vin: String,
        mapper: RideTripRecordMapper
    ) -> [RideTrip] {
        do {
            let vinKind = RideTripRecordMapper.Constants.vinKind
            var descriptor = FetchDescriptor<RideTripRecord>(
                predicate: #Predicate {
                    $0.endedAt != nil
                        && $0.vehicleIdentityKind == vinKind
                        && $0.vehicleIdentityValue == vin
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            descriptor.fetchLimit = Constants.maximumStoredTripsPerVIN
            return try modelContext.fetch(descriptor).compactMap(mapper.mapToDomain)
        } catch {
            report(error)
            return []
        }
    }

    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) -> Bool {
        do {
            let temporaryKind = RideTripRecordMapper.Constants.temporaryKind
            let temporaryValue = temporaryID.uuidString
            let descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
                $0.vehicleIdentityKind == temporaryKind
                    && $0.vehicleIdentityValue == temporaryValue
            })
            for record in try modelContext.fetch(descriptor) {
                record.vehicleIdentityKind = RideTripRecordMapper.Constants.vinKind
                record.vehicleIdentityValue = vin
            }
            let bucketDescriptor = FetchDescriptor<RideEnergyBucketRecord>(predicate: #Predicate {
                $0.vehicleIdentityKind == temporaryKind
                    && $0.vehicleIdentityValue == temporaryValue
            })
            for record in try modelContext.fetch(bucketDescriptor) {
                record.vehicleIdentityKind = RideTripRecordMapper.Constants.vinKind
                record.vehicleIdentityValue = vin
            }
            try modelContext.save()
            try trimHistory(vin: vin)
            return true
        } catch {
            report(error)
            return false
        }
    }
}

private extension RideTripStore {
    func purgeExpiredTemporaryRecords(applicationSessionID: UUID) throws {
        let temporaryKind = RideTripRecordMapper.Constants.temporaryKind
        let descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
            $0.vehicleIdentityKind == temporaryKind
                && $0.applicationSessionID != applicationSessionID
        })
        try modelContext.fetch(descriptor).forEach(modelContext.delete)
        let bucketDescriptor = FetchDescriptor<RideEnergyBucketRecord>(predicate: #Predicate {
            $0.vehicleIdentityKind == temporaryKind
                && $0.applicationSessionID != applicationSessionID
        })
        try modelContext.fetch(bucketDescriptor).forEach(modelContext.delete)
    }

    func fetchActiveRecords() throws -> [RideTripRecord] {
        let descriptor = FetchDescriptor<RideTripRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchRecord(id: UUID) throws -> RideTripRecord? {
        var descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func upsert(_ trip: RideTrip, mapper: RideTripRecordMapper) throws {
        if let record = try fetchRecord(id: trip.id) {
            mapper.update(record, from: trip)
        } else {
            modelContext.insert(mapper.makeRecord(from: trip))
        }
    }

    func fetchEnergyBuckets(
        tripID: UUID,
        mapper: RideEnergyBucketRecordMapper
    ) throws -> [RideEnergyBucket] {
        let descriptor = FetchDescriptor<RideEnergyBucketRecord>(
            predicate: #Predicate { $0.tripID == tripID },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return try modelContext.fetch(descriptor).map(mapper.mapToDomain)
    }

    func syncEnergyBuckets(
        _ trip: RideTrip,
        mapper: RideEnergyBucketRecordMapper
    ) throws {
        let tripID = trip.id
        var latestDescriptor = FetchDescriptor<RideEnergyBucketRecord>(
            predicate: #Predicate { $0.tripID == tripID },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        latestDescriptor.fetchLimit = 1
        let latestRecord = try modelContext.fetch(latestDescriptor).first
        let candidates = trip.energyBuckets.filter { bucket in
            guard let latestRecord else { return true }
            return bucket.startedAt >= latestRecord.startedAt
        }
        for bucket in candidates {
            if bucket.id == latestRecord?.id, let latestRecord {
                mapper.update(latestRecord, from: bucket, trip: trip)
            } else if let record = try fetchEnergyBucket(id: bucket.id) {
                mapper.update(record, from: bucket, trip: trip)
            } else {
                modelContext.insert(mapper.makeRecord(from: bucket, trip: trip))
            }
        }
    }

    func fetchEnergyBucket(id: UUID) throws -> RideEnergyBucketRecord? {
        var descriptor = FetchDescriptor<RideEnergyBucketRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func deleteEnergyBuckets(tripIDs: [UUID]) throws {
        for tripID in tripIDs {
            let descriptor = FetchDescriptor<RideEnergyBucketRecord>(
                predicate: #Predicate { $0.tripID == tripID }
            )
            try modelContext.fetch(descriptor).forEach(modelContext.delete)
        }
    }

    func trimAllConfirmedHistories() throws {
        let vinKind = RideTripRecordMapper.Constants.vinKind
        let descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
            $0.vehicleIdentityKind == vinKind && $0.endedAt != nil
        })
        let vins = Set(try modelContext.fetch(descriptor).map(\.vehicleIdentityValue))
        for vin in vins {
            try trimHistory(vin: vin)
        }
    }

    func trimHistory(vin: String) throws {
        let vinKind = RideTripRecordMapper.Constants.vinKind
        let descriptor = FetchDescriptor<RideTripRecord>(
            predicate: #Predicate {
                $0.vehicleIdentityKind == vinKind
                    && $0.vehicleIdentityValue == vin
                    && $0.endedAt != nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        guard records.count > Constants.maximumStoredTripsPerVIN else { return }
        let discardedRecords = Array(records.dropFirst(Constants.maximumStoredTripsPerVIN))
        try deleteEnergyBuckets(tripIDs: discardedRecords.map(\.id))
        discardedRecords.forEach(modelContext.delete)
        try modelContext.save()
    }

    func report(_ error: Error) {
        Constants.logger.error("Ride trip persistence failed: \(String(describing: error), privacy: .public)")
    }

    enum Constants {
        static let maximumStoredTripsPerVIN = 100
        static let logger = Logger(subsystem: "com.fenr.app", category: "RideTripStore")
    }
}
