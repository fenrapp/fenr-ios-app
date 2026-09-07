import MaintenanceDomain
import Testing

struct MaintenanceReadUseCaseTests {
    @Test("Entry reads distinguish failures from empty results", arguments: [
        MaintenanceReadError.readFailed, .invalidData
    ])
    func propagatesReadError(error: MaintenanceReadError) async {
        let repository = FailingMaintenanceRepository(error: error)
        await #expect(throws: error) {
            try await LoadMaintenanceEntriesUseCase(repository: repository).execute(vin: "FENRTEST000000001")
        }
    }
}
