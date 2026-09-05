import Foundation
import RideSessionDomain
import Testing

@Suite("Trip altitude extrema")
struct RideTripAltitudeTests {
    @Test("Initializes extrema from a valid sample, including below sea level")
    func accumulatesExtrema() {
        let trip = RideTrip(
            vehicleIdentity: .temporary(UUID()), applicationSessionID: UUID(), startedAt: .distantPast
        )
        #expect(trip.minimumAltitudeMeters == nil)
        #expect(trip.maximumAltitudeMeters == nil)
        let first = trip.updatingAltitude(meters: -40)
        #expect(first.minimumAltitudeMeters == -40)
        #expect(first.maximumAltitudeMeters == -40)
        let next = first.updatingAltitude(meters: 125).updatingAltitude(meters: 20)
        #expect(next.minimumAltitudeMeters == -40)
        #expect(next.maximumAltitudeMeters == 125)
        #expect(next.updatingAltitude(meters: nil) == next)
        #expect(next.updatingAltitude(meters: .nan) == next)
        #expect(next.updatingAltitude(meters: .infinity) == next)
    }

    @Test("Pause and completion freeze extrema; resume and identity promotion preserve them")
    func respectsTripLifecycle() {
        let date = Date(timeIntervalSince1970: 1_000)
        let trip = RideTrip(
            vehicleIdentity: .temporary(UUID()), applicationSessionID: UUID(), startedAt: date
        ).updatingAltitude(meters: 50)
        let paused = trip.paused(at: date.addingTimeInterval(1))
        #expect(paused.updatingAltitude(meters: 100) == paused)
        let resumed = paused.resumed(
            at: date.addingTimeInterval(2), odometerKilometers: nil, speedKilometersPerHour: nil
        ).updatingAltitude(meters: 100).promotingVehicleIdentity(to: "FENRTEST000000001")
        #expect(resumed.minimumAltitudeMeters == 50)
        #expect(resumed.maximumAltitudeMeters == 100)
        let completed = resumed.completed(at: date.addingTimeInterval(3))
        #expect(completed.updatingAltitude(meters: -100) == completed)
    }
}
