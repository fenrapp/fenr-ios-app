import BikeDomain
import Foundation
import MaintenanceDomain
import RideSessionDomain
import Testing

@MainActor
@Suite("Debug UI test isolation")
struct DebugUITestIsolationTests {
    @Test("UI test sessions require explicit opt-in and a valid UUID")
    func validatesExplicitNamespace() throws {
        let root = FileManager.default.temporaryDirectory
        #expect(try DebugUITestSession.parse(arguments: ["-uiTestReset"], applicationSupport: root) == nil)
        #expect(throws: DebugUITestSession.ConfigurationError.self) {
            try DebugUITestSession.parse(
                arguments: ["-uiTesting", "-uiTestSession", "../../production"], applicationSupport: root
            )
        }
        let id = UUID()
        let parsed = try DebugUITestSession.parse(
            arguments: ["-uiTesting", "-uiTestSession", id.uuidString, "-uiTestReset"], applicationSupport: root
        )
        let session = try #require(parsed)
        let expectedDirectory = root.appendingPathComponent("UITesting", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        #expect(session.directory == expectedDirectory)
        #expect(session.resetsStorage)
    }

    @Test("Reset clears only its exact session defaults, directory and credential service")
    func resetPreservesOtherNamespaces() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = DebugUITestSession(
            id: UUID(), directory: root.appendingPathComponent("first"), resetsStorage: false
        )
        let second = DebugUITestSession(
            id: UUID(), directory: root.appendingPathComponent("second"), resetsStorage: false
        )
        let firstDefaults = try first.prepare(fileManager: .default, clearCredentials: { _ in })
        let secondDefaults = try second.prepare(fileManager: .default, clearCredentials: { _ in })
        defer {
            firstDefaults.removePersistentDomain(forName: first.suiteName)
            secondDefaults.removePersistentDomain(forName: second.suiteName)
        }
        firstDefaults.set("first", forKey: "marker")
        secondDefaults.set("second", forKey: "marker")
        let firstFile = first.directory.appendingPathComponent("Rides.store")
        let secondFile = second.directory.appendingPathComponent("Rides.store")
        try Data([1]).write(to: firstFile)
        try Data([2]).write(to: secondFile)
        let reset = DebugUITestSession(id: first.id, directory: first.directory, resetsStorage: true)
        var clearedServices: [String] = []

        _ = try reset.prepare(fileManager: .default, clearCredentials: { clearedServices.append($0) })

        #expect(firstDefaults.string(forKey: "marker") == nil)
        #expect(secondDefaults.string(forKey: "marker") == "second")
        #expect(!FileManager.default.fileExists(atPath: firstFile.path))
        #expect(try Data(contentsOf: secondFile) == Data([2]))
        #expect(clearedServices == [first.credentialService])
    }

    @Test("Relaunching the same namespace preserves profile, defaults, rides and maintenance")
    func relaunchPreservesScopedStorage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        let first = try DebugUITestStorageFixture.make(id: id, root: root)
        let other = try DebugUITestStorageFixture.make(id: UUID(), root: root)
        defer { first.clearDefaults(); other.clearDefaults() }
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = BikeProfile(
            vin: "FENRTEST000000001", declaredPowerTier: .alpha,
            alphaEvidence: [.powerAboveStandard], alphaDetectedAt: date
        )
        let profileRepository = DebugBikeProfileRepository(persistence: first.profiles)
        await profileRepository.saveProfile(profile)
        first.defaults.set("imperial", forKey: "measurementFixture")
        let trip = RideTrip(vehicleIdentity: .vin(profile.vin), applicationSessionID: UUID(), startedAt: date)
        let entry = MaintenanceEntry(vin: profile.vin, selection: .init(kind: .chainLubrication), performedAt: date)
        #expect(await first.rides.completeTrip(trip, at: date.addingTimeInterval(60)))
        #expect(await first.maintenance.save(entry))

        let relaunched = try DebugUITestStorageFixture.make(id: id, root: root)

        #expect(relaunched.profiles.load() == profile)
        #expect(relaunched.defaults.string(forKey: "measurementFixture") == "imperial")
        #expect(try await relaunched.rides.loadCompletedTrips(vin: profile.vin).map(\.id) == [trip.id])
        #expect(try await relaunched.maintenance.loadEntries(vin: profile.vin).map(\.id) == [entry.id])
        #expect(other.profiles.load() == nil)
        #expect(other.defaults.string(forKey: "measurementFixture") == nil)
        #expect(try await other.rides.loadCompletedTrips(vin: profile.vin).isEmpty)
        #expect(try await other.maintenance.loadEntries(vin: profile.vin).isEmpty)
    }

    @Test("Read faults remain armed across callers and leave writes and stored data intact")
    func readFaultsRemainArmedUntilExplicitlyDisabled() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try DebugUITestStorageFixture.make(id: UUID(), root: root)
        defer { fixture.clearDefaults() }
        let controls = DebugUITestControls()
        let rides = DebugUITestRideTripRepository(repository: fixture.rides, controls: controls)
        let maintenance = DebugUITestMaintenanceRepository(repository: fixture.maintenance, controls: controls)
        let vin = "FENRTEST000000001"
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let trip = RideTrip(vehicleIdentity: .vin(vin), applicationSessionID: UUID(), startedAt: date)
        let entry = MaintenanceEntry(vin: vin, selection: .init(kind: .chainLubrication), performedAt: date)
        controls.setHistoryReadFailure(true)
        controls.setMaintenanceReadFailure(true)
        #expect(await rides.completeTrip(trip, at: date.addingTimeInterval(60)))
        #expect(await maintenance.save(entry))
        for _ in 0 ..< 2 {
            await #expect(throws: RideTripReadError.readFailed) { try await rides.loadCompletedTrips(vin: vin) }
            await #expect(throws: MaintenanceReadError.readFailed) { try await maintenance.loadEntries(vin: vin) }
        }
        await #expect(throws: RideTripReadError.readFailed) {
            try await rides.loadCompletedTrip(id: trip.id, vin: vin)
        }
        await #expect(throws: MaintenanceReadError.readFailed) {
            try await maintenance.loadEntry(id: entry.id, vin: vin)
        }
        controls.setHistoryReadFailure(false)
        controls.setMaintenanceReadFailure(false)

        #expect(try await rides.loadCompletedTrips(vin: vin).map(\.id) == [trip.id])
        #expect(try await maintenance.loadEntries(vin: vin).map(\.id) == [entry.id])
    }
}
