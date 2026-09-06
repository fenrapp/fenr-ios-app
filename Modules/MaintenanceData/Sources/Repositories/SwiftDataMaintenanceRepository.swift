import Foundation
import MaintenanceDomain
import StarkProtocol

public struct SwiftDataMaintenanceRepository: MaintenanceRepository, Sendable {
    private let store: MaintenanceStore
    private let mapper: MaintenanceEntryRecordMapper

    init(
        store: MaintenanceStore,
        mapper: MaintenanceEntryRecordMapper
    ) {
        self.store = store
        self.mapper = mapper
    }

    public func loadEntries(vin: String) async -> [MaintenanceEntry] {
        guard let vin = normalizedValidVIN(vin) else { return [] }
        return await store.loadEntries(vin: vin, mapper: mapper)
    }

    public func loadEntry(id: UUID, vin: String) async -> MaintenanceEntry? {
        guard let vin = normalizedValidVIN(vin) else { return nil }
        return await store.loadEntry(id: id, vin: vin, mapper: mapper)
    }

    public func save(_ entry: MaintenanceEntry) async -> Bool {
        guard let vin = normalizedValidVIN(entry.vin), entry.isValid else { return false }
        let normalized = MaintenanceEntry(
            id: entry.id,
            vin: vin,
            selection: entry.selection,
            performedAt: entry.performedAt,
            odometerKilometers: entry.odometerKilometers,
            ridingHours: entry.ridingHours,
            notes: entry.notes,
            workshop: entry.workshop,
            costMinorUnits: entry.costMinorUnits,
            currencyCode: entry.currencyCode,
            schedule: entry.schedule,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
        return await store.save(normalized, mapper: mapper)
    }

    public func deleteEntry(id: UUID, vin: String) async -> Bool {
        guard let vin = normalizedValidVIN(vin) else { return false }
        return await store.deleteEntry(id: id, vin: vin)
    }

    private func normalizedValidVIN(_ vin: String) -> String? {
        let normalized = StarkPairingIdentity.normalizedVIN(vin)
        return StarkPairingIdentity.isValidVIN(normalized) ? normalized : nil
    }
}
