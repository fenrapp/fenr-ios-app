import Foundation
import OSLog
import RideSessionDomain
import SwiftData

@ModelActor
actor RideTripStore {
    func prepare(
        context: BikeSessionContext,
        mapper: RideTripRecordMapper
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
                    let restored = trip.rebasingElectrical()
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

    func saveActiveTrip(_ trip: RideTrip, mapper: RideTripRecordMapper) -> Bool {
        guard trip.endedAt == nil else { return false }
        do {
            try upsert(trip, mapper: mapper)
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
        mapper: RideTripRecordMapper
    ) -> Bool {
        do {
            let completed = trip.completed(at: date)
            try upsert(completed, mapper: mapper)
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
        mapper: RideTripRecordMapper
    ) -> Bool {
        do {
            let completed = trip.completed(at: date)
            try upsert(completed, mapper: mapper)
            if let replacement {
                try upsert(replacement, mapper: mapper)
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
        records.dropFirst(Constants.maximumStoredTripsPerVIN).forEach(modelContext.delete)
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
