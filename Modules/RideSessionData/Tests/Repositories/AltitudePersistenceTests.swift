import Foundation
@testable import RideSessionData
import RideSessionDomain
import SwiftData
import Testing

@MainActor
@Suite("Altitude persistence")
struct AltitudePersistenceTests {
    @Test("Upgrades a pre-altitude disk store without inventing extrema or losing trip data")
    func migratesExistingStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("trips.store")
        let tripID = UUID()
        try PreAltitudeStoreFactory.create(at: url, tripID: tripID, sessionID: UUID())
        let container = try RideTripRepositoryFactory.makeModelContainer(storeURL: url)
        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<RideTripRecord>())
        let record = try #require(records.first)
        #expect(records.count == 1)
        #expect(record.id == tripID)
        #expect(record.distanceKilometers == 12)
        #expect(record.minimumAltitudeMeters == nil)
        #expect(record.maximumAltitudeMeters == nil)
    }

    @Test("Restores recorded altitude extrema with the active trip")
    func restoresExtrema() async throws {
        let fixture = try RideSessionDataTestFactory.makeContext()
        let context = BikeSessionContext(applicationSessionID: UUID(), vehicleIdentity: .vin("FENRTEST000000001"))
        let trip = RideTrip(
            vehicleIdentity: context.vehicleIdentity, applicationSessionID: context.applicationSessionID,
            startedAt: Date(timeIntervalSince1970: 1_000)
        ).updatingAltitude(meters: -50).updatingAltitude(meters: 1_250)
        #expect(await fixture.repository.saveActiveTrip(trip))
        let restored = try #require(await fixture.repository.prepare(context: context))
        #expect(restored.minimumAltitudeMeters == -50)
        #expect(restored.maximumAltitudeMeters == 1_250)
    }
}
