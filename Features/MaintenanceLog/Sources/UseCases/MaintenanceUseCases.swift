import MaintenanceDomain

public struct MaintenanceUseCases: Sendable {
    public let loadEntries: LoadMaintenanceEntriesUseCase
    public let saveEntry: SaveMaintenanceEntryUseCase
    public let deleteEntry: DeleteMaintenanceEntryUseCase

    public init(
        loadEntries: LoadMaintenanceEntriesUseCase,
        saveEntry: SaveMaintenanceEntryUseCase,
        deleteEntry: DeleteMaintenanceEntryUseCase
    ) {
        self.loadEntries = loadEntries
        self.saveEntry = saveEntry
        self.deleteEntry = deleteEntry
    }
}
