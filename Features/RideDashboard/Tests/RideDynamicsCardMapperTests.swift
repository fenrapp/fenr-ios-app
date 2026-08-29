import EnvironmentDomain
import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import SettingsDomain
import Testing
import VehicleSession

@Suite("Ride dynamics card mapper")
struct RideDynamicsCardMapperTests {
    @Test("Maps live motion, trip peaks, GPS course, and metric altitude")
    func mapsLiveState() {
        let trip = RideTrip(
            vehicleIdentity: .vin("FENRTEST000000001"),
            applicationSessionID: UUID(),
            startedAt: .now,
            maximumLeftLeanDegrees: 32,
            maximumRightLeanDegrees: 27,
            maximumUphillPitchDegrees: 11,
            maximumDownhillPitchDegrees: 8
        )
        let snapshot = RideSessionSnapshot(
            trip: trip,
            vehicleIdentity: trip.vehicleIdentity,
            motion: .init(
                rollDegrees: -18,
                pitchDegrees: 6,
                headingDegrees: 336,
                altitudeMeters: 1_045,
                coordinate: GeographicCoordinate(
                    latitudeDegrees: 40.426_389,
                    longitudeDegrees: -3.703_889
                ),
                headingSource: .gpsCourse,
                availability: .available,
                observedAt: .now
            )
        )

        let state = RideDynamicsCardMapper(locale: .init(identifier: "en_GB")).map(snapshot)

        #expect(state.status == .live)
        #expect(state.leanText == "18°")
        #expect(state.leanDirectionText == "LEFT")
        #expect(state.maximumLeftLeanText == "32°")
        #expect(state.pitchDirectionText == "UP")
        #expect(state.cardinalDirectionText == "NNW")
        #expect(state.isHeadingAvailable)
        #expect(state.headingSourceText == "GPS")
        #expect(state.altitudeText == "1,045 m")
        #expect(state.latitudeText == "40°25′35″ N")
        #expect(state.longitudeText == "3°42′14″ W")
        #expect(state.canCalibrate)
    }

    @Test("Formats coordinate hemispheres and carries rounded seconds")
    func formatsCoordinates() {
        let snapshot = RideSessionSnapshot(
            vehicleIdentity: .vin("FENRTEST000000001"),
            motion: .init(
                coordinate: GeographicCoordinate(
                    latitudeDegrees: -33.999_861_2,
                    longitudeDegrees: 151.209_167
                )
            )
        )

        let state = RideDynamicsCardMapper(locale: .init(identifier: "en_GB")).map(snapshot)

        #expect(state.latitudeText == "34°0′0″ S")
        #expect(state.longitudeText == "151°12′33″ E")
        #expect(!state.isHeadingAvailable)
        #expect(state.headingSourceText == "NO COURSE")
        #expect(state.altitudeText == nil)
    }

    @Test("Requires a confirmed VIN before enabling calibration")
    func requiresConfirmedVINForCalibration() {
        let snapshot = RideSessionSnapshot(
            vehicleIdentity: .temporary(UUID()),
            motion: .init(
                headingSource: .unavailable,
                availability: .calibrating,
                observedAt: .now
            )
        )

        let state = RideDynamicsCardMapper(locale: .init(identifier: "en_GB")).map(snapshot)

        #expect(state.status == .calibrating)
        #expect(!state.canCalibrate)
    }

    @Test("Maps every motion availability to a distinct instrument state")
    func mapsMotionAvailabilityStates() {
        let mapper = RideDynamicsCardMapper(locale: .init(identifier: "en_GB"))
        let cases: [(VehicleMotionAvailability, DashboardRideDynamicsViewData.Status)] = [
            (.unavailable, .unavailable),
            (.calibrating, .calibrating),
            (.zeroing, .zeroing),
            (.available, .live),
            (.stale, .signalLost)
        ]

        for (availability, expectedStatus) in cases {
            let snapshot = RideSessionSnapshot(
                vehicleIdentity: .temporary(UUID()),
                motion: .init(availability: availability)
            )

            #expect(mapper.map(snapshot).status == expectedStatus)
        }
    }
}
