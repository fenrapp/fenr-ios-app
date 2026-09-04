import Foundation
import MaintenanceDomain

actor MaintenanceTestRepository: MaintenanceRepository {
    private var entries: [MaintenanceEntry]
    private let operation: ControllableMaintenanceOperation
    private(set) var savedEntries: [MaintenanceEntry] = []

    init(entries: [MaintenanceEntry], operation: ControllableMaintenanceOperation) {
        self.entries = entries
        self.operation = operation
    }

    func loadEntries(vin: String) async -> [MaintenanceEntry] {
        await operation.perform(.load)
        return entries.filter { $0.vin == vin }.sorted { $0.performedAt > $1.performedAt }
    }

    func loadEntry(id: UUID, vin: String) async -> MaintenanceEntry? {
        entries.first { $0.id == id && $0.vin == vin }
    }

    func save(_ entry: MaintenanceEntry) async -> Bool {
        await operation.perform(.save)
        savedEntries.append(entry)
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        return true
    }

    func deleteEntry(id: UUID, vin: String) async -> Bool {
        await operation.perform(.delete)
        guard entries.contains(where: { $0.id == id && $0.vin == vin }) else { return false }
        entries.removeAll { $0.id == id && $0.vin == vin }
        return true
    }
}
