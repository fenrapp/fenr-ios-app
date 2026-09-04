import Foundation

public protocol MaintenanceRepository: Sendable {
    func loadEntries(vin: String) async -> [MaintenanceEntry]
    func loadEntry(id: UUID, vin: String) async -> MaintenanceEntry?
    @discardableResult
    func save(_ entry: MaintenanceEntry) async -> Bool
    @discardableResult
    func deleteEntry(id: UUID, vin: String) async -> Bool
}

public struct LoadMaintenanceEntriesUseCase: Sendable {
    private let repository: any MaintenanceRepository

    public init(repository: any MaintenanceRepository) {
        self.repository = repository
    }

    public func execute(vin: String) async -> [MaintenanceEntry] {
        await repository.loadEntries(vin: vin)
    }
}

public struct SaveMaintenanceEntryUseCase: Sendable {
    private let repository: any MaintenanceRepository

    public init(repository: any MaintenanceRepository) {
        self.repository = repository
    }

    public func execute(_ entry: MaintenanceEntry) async -> Bool {
        guard entry.isValid else { return false }
        return await repository.save(entry)
    }
}

public struct DeleteMaintenanceEntryUseCase: Sendable {
    private let repository: any MaintenanceRepository

    public init(repository: any MaintenanceRepository) {
        self.repository = repository
    }

    public func execute(id: UUID, vin: String) async -> Bool {
        await repository.deleteEntry(id: id, vin: vin)
    }
}
