import Foundation
import MaintenanceDomain

public struct MaintenanceEntryRecordMapper: Sendable {
    public init() {}

    func mapToDomain(_ record: MaintenanceEntryRecord) -> MaintenanceEntry? {
        guard let kind = MaintenanceKind(rawValue: record.kindRawValue) else { return nil }
        let schedule = MaintenanceSchedule(
            dueDate: record.dueDate,
            dueOdometerKilometers: record.dueOdometerKilometers,
            dueRidingHours: record.dueRidingHours,
            completedAt: record.reminderCompletedAt
        )
        let entry = MaintenanceEntry(
            id: record.id,
            vin: record.vin,
            selection: .init(kind: kind, customName: record.customName),
            performedAt: record.performedAt,
            odometerKilometers: record.odometerKilometers,
            ridingHours: record.ridingHours,
            notes: record.notes,
            workshop: record.workshop,
            costMinorUnits: record.costMinorUnits,
            currencyCode: record.currencyCode,
            schedule: schedule.hasDueValue ? schedule : nil,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
        return entry.isValid ? entry : nil
    }

    func makeRecord(from entry: MaintenanceEntry) -> MaintenanceEntryRecord {
        let record = MaintenanceEntryRecord(
            id: entry.id,
            vin: entry.vin,
            kindRawValue: entry.selection.kind.rawValue,
            matchingKey: entry.selection.matchingKey,
            performedAt: entry.performedAt,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
        update(record, from: entry)
        return record
    }

    func update(_ record: MaintenanceEntryRecord, from entry: MaintenanceEntry) {
        record.vin = entry.vin
        record.kindRawValue = entry.selection.kind.rawValue
        record.customName = entry.selection.customName
        record.matchingKey = entry.selection.matchingKey
        record.performedAt = entry.performedAt
        record.odometerKilometers = entry.odometerKilometers
        record.ridingHours = entry.ridingHours
        record.notes = entry.notes
        record.workshop = entry.workshop
        record.costMinorUnits = entry.costMinorUnits
        record.currencyCode = entry.currencyCode
        record.dueDate = entry.schedule?.dueDate
        record.dueOdometerKilometers = entry.schedule?.dueOdometerKilometers
        record.dueRidingHours = entry.schedule?.dueRidingHours
        record.reminderCompletedAt = entry.schedule?.completedAt
        record.updatedAt = entry.updatedAt
    }
}
