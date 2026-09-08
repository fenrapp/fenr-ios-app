import Foundation
import MaintenanceDomain
import Testing

@MainActor
struct MaintenanceReadFailureTests {
    private let vin = "FENRTEST000000001"

    @Test("A successful empty query and missing detail remain ordinary results")
    func emptyStoreHasNoEntries() async throws {
        let context = try MaintenanceReadTestFactory.makeContext()
        #expect(try await context.repository.loadEntries(vin: vin).isEmpty)
        #expect(try await context.repository.loadEntry(id: UUID(), vin: vin) == nil)
    }

    @Test("Unreadable entries fail without silently dropping or changing stored records")
    func corruptEntryIsReportedAndPreserved() async throws {
        let context = try MaintenanceReadTestFactory.makeContext()
        let validID = try context.persistRecord(vin: vin, kind: MaintenanceKind.tires.rawValue)
        let invalidID = try context.persistRecord(vin: vin, kind: "invalid-kind")
        let original = try context.storedKinds()
        await #expect(throws: MaintenanceReadError.invalidData) {
            try await context.repository.loadEntries(vin: vin)
        }
        await #expect(throws: MaintenanceReadError.invalidData) {
            try await context.repository.loadEntry(id: invalidID, vin: vin)
        }
        #expect(try await context.repository.loadEntry(id: validID, vin: vin)?.id == validID)
        #expect(try await context.repository.loadEntry(id: invalidID, vin: "FENRTEST000000002") == nil)
        #expect(try context.storedKinds() == original)
    }

    @Test("Cancellation remains cancellation instead of a storage failure")
    func preservesCancellation() async throws {
        let context = try MaintenanceReadTestFactory.makeContext()
        let read = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await context.repository.loadEntries(vin: vin)
        }
        await #expect(throws: CancellationError.self) { try await read.value }
    }
}
