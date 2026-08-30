import Foundation
import RideSessionDomain
import SwiftData

extension RideTripStore {
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

    func deleteTripRecordAndEnergyBuckets(_ record: RideTripRecord) throws {
        try deleteEnergyBuckets(tripIDs: [record.id])
        modelContext.delete(record)
    }

    private func fetchEnergyBucket(id: UUID) throws -> RideEnergyBucketRecord? {
        var descriptor = FetchDescriptor<RideEnergyBucketRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func deleteEnergyBuckets(tripIDs: [UUID]) throws {
        for tripID in tripIDs {
            let descriptor = FetchDescriptor<RideEnergyBucketRecord>(
                predicate: #Predicate { $0.tripID == tripID }
            )
            try modelContext.fetch(descriptor).forEach(modelContext.delete)
        }
    }
}
