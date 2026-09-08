import Foundation
import RideSessionDomain
import SwiftData

extension RideTripStore {
    func loadCompletedTrips(
        vin: String,
        mapper: RideTripRecordMapper
    ) throws -> [RideTrip] {
        try Task.checkCancellation()
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
            return try modelContext.fetch(descriptor).map { record in
                guard let trip = mapper.mapToDomain(record) else { throw RideTripReadError.invalidData }
                return trip
            }
        } catch let error as RideTripReadError {
            throw error
        } catch {
            throw RideTripReadError.readFailed
        }
    }

    func loadCompletedTrip(
        id: UUID,
        vin: String,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) throws -> RideTrip? {
        try Task.checkCancellation()
        do {
            let vinKind = RideTripRecordMapper.Constants.vinKind
            var descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
                $0.id == id
                    && $0.endedAt != nil
                    && $0.vehicleIdentityKind == vinKind
                    && $0.vehicleIdentityValue == vin
            })
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first else { return nil }
            guard let trip = mapper.mapToDomain(record) else { throw RideTripReadError.invalidData }
            return trip.restoringEnergyBuckets(
                try fetchEnergyBuckets(tripID: id, mapper: energyBucketMapper)
            )
        } catch let error as RideTripReadError {
            throw error
        } catch {
            throw RideTripReadError.readFailed
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
