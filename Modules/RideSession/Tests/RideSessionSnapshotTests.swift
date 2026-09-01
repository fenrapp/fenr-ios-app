import Foundation
@testable import RideSession
import RideSessionDomain
import Testing

@Suite("Ride session snapshot")
struct RideSessionSnapshotTests {
    @Test("Defaults to an empty motorcycle-speed session")
    func defaults() {
        let identity = RideVehicleIdentity.temporary(UUID())
        let snapshot = RideSessionSnapshot(vehicleIdentity: identity)

        #expect(snapshot.vehicleIdentity == identity)
        #expect(snapshot.trip == nil)
        #expect(snapshot.resolvedSpeedKilometersPerHour == nil)
        #expect(snapshot.livePowerSamples.isEmpty)
        #expect(!snapshot.isCanonicalTelemetryAvailable)
    }
}
