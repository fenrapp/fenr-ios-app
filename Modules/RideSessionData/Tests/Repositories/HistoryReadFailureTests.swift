import Foundation
@testable import RideSessionData
import RideSessionDomain
import Testing

@MainActor
struct HistoryReadFailureTests {
    @Test("An empty history and a missing ride detail are successful reads")
    func emptyHistory() async throws {
        let context = try RideSessionDataTestFactory.makeContext()
        #expect(try await context.repository.loadCompletedTrips(vin: RideSessionDataFixtures.firstVIN).isEmpty)
        #expect(try await context.repository.loadCompletedTrip(
            id: UUID(), vin: RideSessionDataFixtures.firstVIN
        ) == nil)
    }

    @Test("A rejected persisted identity is a read error and its record is preserved")
    func invalidIdentityIsReported() async throws {
        let context = try RideSessionDataTestFactory.makeContext()
        let record = RideSessionDataTestFactory.makeTripRecord(
            identityKind: "vin", identityValue: "", applicationSessionID: UUID()
        )
        record.endedAt = record.updatedAt
        try context.persist(tripRecords: [record])
        let original = try context.tripSnapshots()
        let id = record.id
        await #expect(throws: RideTripReadError.invalidData) {
            try await context.repository.loadCompletedTrips(vin: "")
        }
        await #expect(throws: RideTripReadError.invalidData) {
            try await context.repository.loadCompletedTrip(id: id, vin: "")
        }
        #expect(try context.tripSnapshots() == original)
    }

    @Test("Cancellation is not converted into an empty history or a read failure")
    func cancellationRemainsCancellation() async throws {
        let context = try RideSessionDataTestFactory.makeContext()
        let read = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await context.repository.loadCompletedTrips(vin: RideSessionDataFixtures.firstVIN)
        }
        await #expect(throws: CancellationError.self) { try await read.value }
    }
}
