import Foundation
import MaintenanceDomain

struct DebugUITestMaintenanceRepository: MaintenanceRepository {
    let repository: any MaintenanceRepository
    let controls: DebugUITestControls

    func loadEntries(vin: String) async throws -> [MaintenanceEntry] {
        guard await !controls.maintenanceReadFailure else { throw MaintenanceReadError.readFailed }
        return try await repository.loadEntries(vin: vin)
    }

    func loadEntry(id: UUID, vin: String) async throws -> MaintenanceEntry? {
        guard await !controls.maintenanceReadFailure else { throw MaintenanceReadError.readFailed }
        return try await repository.loadEntry(id: id, vin: vin)
    }

    func save(_ entry: MaintenanceEntry) async -> Bool { await repository.save(entry) }

    func deleteEntry(id: UUID, vin: String) async -> Bool {
        await repository.deleteEntry(id: id, vin: vin)
    }
}
