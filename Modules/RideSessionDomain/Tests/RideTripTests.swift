import Foundation
import RideSessionDomain
import Testing

@Suite("Ride trip")
struct RideTripTests {
    @Test("Uses odometer for distance and the resolved speed sample for speed metrics")
    func updatesMetrics() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let trip = RideTrip(
            applicationSessionID: UUID(),
            startedAt: startedAt,
            startingOdometerKilometers: 100,
            maximumSpeedKilometersPerHour: 12
        ).updating(
            at: startedAt,
            odometerKilometers: 100,
            speedKilometersPerHour: 42
        )

        let updated = trip.updating(
            at: startedAt.addingTimeInterval(600),
            odometerKilometers: 105,
            speedKilometersPerHour: 42
        )

        #expect(updated.distanceKilometers == 5)
        #expect(updated.elapsedSeconds == 600)
        #expect(updated.averageSpeedKilometersPerHour == 42)
        #expect(updated.maximumSpeedKilometersPerHour == 42)
    }

    @Test("Builds a time-weighted average without treating missing samples as zero")
    func averagesResolvedSpeedSamples() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let initialSample = RideTrip(
            applicationSessionID: UUID(),
            startedAt: startedAt
        ).updating(
            at: startedAt,
            odometerKilometers: nil,
            speedKilometersPerHour: 30
        )
        let secondSample = initialSample.updating(
            at: startedAt.addingTimeInterval(30),
            odometerKilometers: nil,
            speedKilometersPerHour: 60
        )
        let missingSample = secondSample.updating(
            at: startedAt.addingTimeInterval(60),
            odometerKilometers: nil,
            speedKilometersPerHour: nil
        )
        let continuedGap = missingSample.updating(
            at: startedAt.addingTimeInterval(90),
            odometerKilometers: nil,
            speedKilometersPerHour: nil
        )

        #expect(secondSample.averageSpeedKilometersPerHour == 30)
        #expect(missingSample.averageSpeedKilometersPerHour == 45)
        #expect(continuedGap.averageSpeedKilometersPerHour == 45)
        #expect(continuedGap.speedSampleDurationSeconds == 60)
    }

    @Test("Ignores invalid readings without moving accumulated values backwards")
    func ignoresInvalidReadings() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let trip = RideTrip(
            applicationSessionID: UUID(),
            startedAt: startedAt,
            startingOdometerKilometers: 100,
            distanceKilometers: 4,
            elapsedSeconds: 300,
            averageSpeedKilometersPerHour: 48,
            maximumSpeedKilometersPerHour: 50
        )

        let updated = trip.updating(
            at: startedAt.addingTimeInterval(200),
            odometerKilometers: 99,
            speedKilometersPerHour: -3
        )

        #expect(updated.distanceKilometers == 4)
        #expect(updated.elapsedSeconds == 300)
        #expect(updated.maximumSpeedKilometersPerHour == 50)
    }

    @Test("Completing a trip freezes it at the completion time")
    func completesTrip() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = startedAt.addingTimeInterval(90)
        let completed = RideTrip(
            applicationSessionID: UUID(),
            startedAt: startedAt
        ).completed(at: endedAt)

        #expect(completed.endedAt == endedAt)
        #expect(completed.elapsedSeconds == 90)
        #expect(completed.updating(
            at: endedAt.addingTimeInterval(30),
            odometerKilometers: 10,
            speedKilometersPerHour: 20
        ) == completed)
    }

    @Test("Pause excludes stopped time and odometer movement after resume")
    func pausesAndResumesTrip() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let beforePause = RideTrip(
            applicationSessionID: UUID(),
            startedAt: startedAt,
            startingOdometerKilometers: 100
        ).updating(
            at: startedAt,
            odometerKilometers: 100,
            speedKilometersPerHour: 40
        ).updating(
            at: startedAt.addingTimeInterval(60),
            odometerKilometers: 101,
            speedKilometersPerHour: 40
        )
        let paused = beforePause.paused(at: startedAt.addingTimeInterval(60))

        let ignoredUpdate = paused.updating(
            at: startedAt.addingTimeInterval(120),
            odometerKilometers: 103,
            speedKilometersPerHour: 80
        )
        let resumed = ignoredUpdate.resumed(
            at: startedAt.addingTimeInterval(120),
            odometerKilometers: 103,
            speedKilometersPerHour: 50
        )
        let updated = resumed.updating(
            at: startedAt.addingTimeInterval(180),
            odometerKilometers: 104,
            speedKilometersPerHour: 50
        )

        #expect(ignoredUpdate == paused)
        #expect(updated.distanceKilometers == 2)
        #expect(updated.elapsedSeconds == 120)
        #expect(updated.averageSpeedKilometersPerHour == 45)
        #expect(updated.maximumSpeedKilometersPerHour == 50)
        #expect(!updated.isPaused)
    }

    @Test("Completing a paused trip preserves its frozen metrics")
    func completesPausedTrip() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let paused = RideTrip(
            applicationSessionID: UUID(),
            startedAt: startedAt
        ).paused(at: startedAt.addingTimeInterval(30))

        let completed = paused.completed(at: startedAt.addingTimeInterval(90))

        #expect(completed.endedAt == startedAt.addingTimeInterval(90))
        #expect(completed.elapsedSeconds == 30)
        #expect(!completed.isPaused)
    }
}
