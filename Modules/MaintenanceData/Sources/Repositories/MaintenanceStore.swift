import Foundation
import MaintenanceDomain
import SwiftData

@ModelActor
actor MaintenanceStore {
    func loadEntries(vin: String, mapper: MaintenanceEntryRecordMapper) throws -> [MaintenanceEntry] {
        try Task.checkCancellation()
        do {
            let descriptor = FetchDescriptor<MaintenanceEntryRecord>(
                predicate: #Predicate { $0.vin == vin },
                sortBy: [SortDescriptor(\.performedAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor).map { record in
                guard let entry = mapper.mapToDomain(record) else { throw MaintenanceReadError.invalidData }
                return entry
            }
        } catch let error as MaintenanceReadError {
            throw error
        } catch {
            throw MaintenanceReadError.readFailed
        }
    }

    func loadEntry(id: UUID, vin: String, mapper: MaintenanceEntryRecordMapper) throws -> MaintenanceEntry? {
        try Task.checkCancellation()
        do {
            var descriptor = FetchDescriptor<MaintenanceEntryRecord>(predicate: #Predicate {
                $0.id == id && $0.vin == vin
            })
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first else { return nil }
            guard let entry = mapper.mapToDomain(record) else { throw MaintenanceReadError.invalidData }
            return entry
        } catch let error as MaintenanceReadError {
            throw error
        } catch {
            throw MaintenanceReadError.readFailed
        }
    }

    func save(_ entry: MaintenanceEntry, mapper: MaintenanceEntryRecordMapper) -> Bool {
        do {
            let entryID = entry.id
            let vin = entry.vin
            var existingDescriptor = FetchDescriptor<MaintenanceEntryRecord>(predicate: #Predicate {
                $0.id == entryID && $0.vin == vin
            })
            existingDescriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(existingDescriptor).first {
                mapper.update(existing, from: entry)
            } else {
                modelContext.insert(mapper.makeRecord(from: entry))
            }

            let vinRecords = try modelContext.fetch(FetchDescriptor<MaintenanceEntryRecord>(
                predicate: #Predicate { $0.vin == vin }
            ))
            reconcileReminderCompletion(in: vinRecords)
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    func deleteEntry(id: UUID, vin: String) -> Bool {
        do {
            var descriptor = FetchDescriptor<MaintenanceEntryRecord>(predicate: #Predicate {
                $0.id == id && $0.vin == vin
            })
            descriptor.fetchLimit = 1
            guard let record = try modelContext.fetch(descriptor).first else { return false }
            let vinRecords = try modelContext.fetch(FetchDescriptor<MaintenanceEntryRecord>(
                predicate: #Predicate { $0.vin == vin }
            ))
            modelContext.delete(record)
            reconcileReminderCompletion(in: vinRecords.filter { $0.id != id })
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

    private func reconcileReminderCompletion(in records: [MaintenanceEntryRecord]) {
        for record in records {
            guard record.dueDate != nil
                    || record.dueOdometerKilometers != nil
                    || record.dueRidingHours != nil else {
                record.reminderCompletedAt = nil
                continue
            }
            record.reminderCompletedAt = records
                .filter { candidate in
                    candidate.id != record.id
                        && candidate.matchingKey == record.matchingKey
                        && isLater(candidate, than: record)
                }
                .min { lhs, rhs in isLater(rhs, than: lhs) }
                .map(\.performedAt)
        }
    }

    private func isLater(_ candidate: MaintenanceEntryRecord, than record: MaintenanceEntryRecord) -> Bool {
        if candidate.performedAt != record.performedAt {
            return candidate.performedAt > record.performedAt
        }
        if candidate.createdAt != record.createdAt {
            return candidate.createdAt > record.createdAt
        }
        return candidate.id.uuidString > record.id.uuidString
    }
}
