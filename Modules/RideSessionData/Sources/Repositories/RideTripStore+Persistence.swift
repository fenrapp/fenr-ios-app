import Foundation
import RideSessionDomain
import SwiftData

extension RideTripStore {
    func fetchActiveRecords() throws -> [RideTripRecord] {
        let descriptor = FetchDescriptor<RideTripRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func upsert(_ trip: RideTrip, mapper: RideTripRecordMapper) throws {
        if let record = try fetchRecord(id: trip.id) {
            mapper.update(record, from: trip)
        } else {
            modelContext.insert(mapper.makeRecord(from: trip))
        }
    }

    func handlePersistenceError(_ error: Error) {
        modelContext.rollback()
    }

    private func fetchRecord(id: UUID) throws -> RideTripRecord? {
        var descriptor = FetchDescriptor<RideTripRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

}
