import Foundation
import RideSessionDomain
import SwiftData

extension RideTripStore {
    func loadCompletedTrips(
        vin: String,
        mapper: RideTripRecordMapper
    ) -> [RideTrip] {
        do {
            let vinKind = RideTripRecordMapper.Constants.vinKind
            let descriptor = FetchDescriptor<RideTripRecord>(
                predicate: #Predicate {
                    $0.endedAt != nil
                        && $0.vehicleIdentityKind == vinKind
                        && $0.vehicleIdentityValue == vin
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor).compactMap(mapper.mapToDomain)
        } catch {
            handlePersistenceError(error)
            return []
        }
    }

    func loadCompletedTrip(
        id: UUID,
        vin: String,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) -> RideTrip? {
        do {
            let vinKind = RideTripRecordMapper.Constants.vinKind
            var descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
                $0.id == id
                    && $0.endedAt != nil
                    && $0.vehicleIdentityKind == vinKind
                    && $0.vehicleIdentityValue == vin
            })
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first,
                  let trip = mapper.mapToDomain(record) else { return nil }
            return trip.restoringEnergyBuckets(
                try fetchEnergyBuckets(tripID: id, mapper: energyBucketMapper)
            )
        } catch {
            handlePersistenceError(error)
            return nil
        }
    }

    func deleteCompletedTrip(id: UUID, vin: String) -> Bool {
        do {
            let vinKind = RideTripRecordMapper.Constants.vinKind
            var descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
                $0.id == id
                    && $0.endedAt != nil
                    && $0.vehicleIdentityKind == vinKind
                    && $0.vehicleIdentityValue == vin
            })
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first else { return false }
            try deleteTripRecordAndEnergyBuckets(record)
            try modelContext.save()
            return true
        } catch {
            handlePersistenceError(error)
            return false
        }
    }
}
