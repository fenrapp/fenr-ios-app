import Foundation
import MaintenanceData
import MaintenanceDomain
import Testing

struct SwiftDataMaintenanceRepositoryTests {
    @Test("Entries are isolated by VIN and sorted newest first")
    func entriesAreIsolatedByVIN() async throws {
        let repository = try MaintenanceRepositoryFactory.make(isStoredInMemoryOnly: true)
        let older = entry(vin: Constants.firstVIN, date: Date(timeIntervalSince1970: 10))
        let newer = entry(vin: Constants.firstVIN, date: Date(timeIntervalSince1970: 20))
        let otherBike = entry(vin: Constants.secondVIN, date: Date(timeIntervalSince1970: 30))

        #expect(await repository.save(older))
        #expect(await repository.save(newer))
        #expect(await repository.save(otherBike))

        #expect(try await repository.loadEntries(vin: Constants.firstVIN).map(\.id) == [newer.id, older.id])
        #expect(try await repository.loadEntries(vin: Constants.secondVIN).map(\.id) == [otherBike.id])
    }

    @Test("Saving a later entry completes matching pending reminders")
    func completesMatchingReminder() async throws {
        let repository = try MaintenanceRepositoryFactory.make(isStoredInMemoryOnly: true)
        let first = MaintenanceEntry(
            vin: Constants.firstVIN,
            selection: .init(kind: .brakeFluid),
            performedAt: Date(timeIntervalSince1970: 10),
            schedule: .init(dueDate: Date(timeIntervalSince1970: 200))
        )
        #expect(await repository.save(first))

        let second = MaintenanceEntry(
            vin: Constants.firstVIN,
            selection: .init(kind: .brakeFluid),
            performedAt: Date(timeIntervalSince1970: 90)
        )
        #expect(await repository.save(second))

        let reloaded = try #require(try await repository.loadEntry(id: first.id, vin: Constants.firstVIN))
        #expect(reloaded.schedule?.completedAt == second.performedAt)
    }

    @Test("Deleting or reclassifying a completing entry reopens the prior reminder")
    func recalculatesReminderCompletion() async throws {
        let repository = try MaintenanceRepositoryFactory.make(isStoredInMemoryOnly: true)
        let reminder = MaintenanceEntry(
            vin: Constants.firstVIN,
            selection: .init(kind: .brakeFluid),
            performedAt: Date(timeIntervalSince1970: 10),
            schedule: .init(dueDate: Date(timeIntervalSince1970: 200))
        )
        let service = MaintenanceEntry(
            vin: Constants.firstVIN,
            selection: .init(kind: .brakeFluid),
            performedAt: Date(timeIntervalSince1970: 90)
        )
        #expect(await repository.save(reminder))
        #expect(await repository.save(service))
        #expect(try await repository.loadEntry(id: reminder.id, vin: Constants.firstVIN)?.schedule?.completedAt != nil)

        let reclassified = MaintenanceEntry(
            id: service.id,
            vin: service.vin,
            selection: .init(kind: .tires),
            performedAt: service.performedAt,
            createdAt: service.createdAt,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        #expect(await repository.save(reclassified))
        #expect(try await repository.loadEntry(id: reminder.id, vin: Constants.firstVIN)?.schedule?.completedAt == nil)

        let laterService = MaintenanceEntry(
            vin: Constants.firstVIN,
            selection: .init(kind: .brakeFluid),
            performedAt: Date(timeIntervalSince1970: 110)
        )
        #expect(await repository.save(laterService))
        #expect(await repository.deleteEntry(id: laterService.id, vin: Constants.firstVIN))
        #expect(try await repository.loadEntry(id: reminder.id, vin: Constants.firstVIN)?.schedule?.completedAt == nil)
    }

    @Test("Invalid VINs and cross-bike deletion are rejected")
    func validatesIdentity() async throws {
        let repository = try MaintenanceRepositoryFactory.make(isStoredInMemoryOnly: true)
        let saved = entry(vin: Constants.firstVIN, date: Date())
        #expect(await repository.save(saved))
        #expect(!(await repository.deleteEntry(id: saved.id, vin: Constants.secondVIN)))
        #expect(try await repository.loadEntries(vin: "invalid").isEmpty)
    }

    private func entry(vin: String, date: Date) -> MaintenanceEntry {
        MaintenanceEntry(
            vin: vin,
            selection: .init(kind: .tires),
            performedAt: date
        )
    }

    private enum Constants {
        static let firstVIN = "FENRTEST000000001"
        static let secondVIN = "FENRTEST000000002"
    }
}
