import Foundation
import SwiftData

extension RideTripStore {
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
            return true
        } catch {
            handlePersistenceError(error)
            return false
        }
    }

    func purgeExpiredTemporaryRecords(applicationSessionID: UUID) throws {
        let temporaryKind = RideTripRecordMapper.Constants.temporaryKind
        let descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate {
            $0.vehicleIdentityKind == temporaryKind
                && $0.applicationSessionID != applicationSessionID
        })
        for record in try modelContext.fetch(descriptor) {
            try deleteTripRecordAndEnergyBuckets(record)
        }
        let bucketDescriptor = FetchDescriptor<RideEnergyBucketRecord>(predicate: #Predicate {
            $0.vehicleIdentityKind == temporaryKind
                && $0.applicationSessionID != applicationSessionID
        })
        try modelContext.fetch(bucketDescriptor).forEach(modelContext.delete)
    }
}
