import Foundation
import MaintenanceDomain

struct FailingMaintenanceRepository: MaintenanceRepository {
    let error: MaintenanceReadError

    func loadEntries(vin: String) async throws -> [MaintenanceEntry] { throw error }
    func loadEntry(id: UUID, vin: String) async throws -> MaintenanceEntry? { throw error }
    func save(_ entry: MaintenanceEntry) async -> Bool { false }
    func deleteEntry(id: UUID, vin: String) async -> Bool { false }
}
