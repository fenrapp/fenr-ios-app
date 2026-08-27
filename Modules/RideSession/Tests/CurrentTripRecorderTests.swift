import BikeDomain
import Foundation
@testable import RideSession
import Testing

@Suite("Current trip recorder")
struct CurrentTripRecorderTests {
    @Test("Starts only when a drive mode is engaged")
    func startsInDriveMode() {
        let sessionID = UUID()
        let date = Date(timeIntervalSince1970: 1_000)
        var recorder = CurrentTripRecorder(applicationSessionID: sessionID)

        #expect(recorder.record(
            runState: .neutral,
            at: date,
            odometerKilometers: 100,
            speedKilometersPerHour: 0
        ) == nil)

        let trip = recorder.record(
            runState: .on,
            at: date,
            odometerKilometers: 100,
            speedKilometersPerHour: 8
        )

        #expect(trip?.applicationSessionID == sessionID)
        #expect(trip?.startingOdometerKilometers == 100)
        #expect(trip?.maximumSpeedKilometersPerHour == 8)
    }

    @Test("Continues accumulating after returning to neutral")
    func continuesInNeutral() {
        let date = Date(timeIntervalSince1970: 1_000)
        var recorder = CurrentTripRecorder(applicationSessionID: UUID())
        _ = recorder.record(
            runState: .on,
            at: date,
            odometerKilometers: 100,
            speedKilometersPerHour: 10
        )

        let trip = recorder.record(
            runState: .neutral,
            at: date.addingTimeInterval(360),
            odometerKilometers: 103,
            speedKilometersPerHour: 0
        )

        #expect(trip?.distanceKilometers == 3)
        #expect(trip?.elapsedSeconds == 360)
        #expect(trip?.averageSpeedKilometersPerHour == 10)
    }

    @Test(arguments: [BikeRunState.crawlForward, .crawlReverse])
    func crawlModesStartTrip(runState: BikeRunState) {
        var recorder = CurrentTripRecorder(applicationSessionID: UUID())

        #expect(recorder.record(
            runState: runState,
            at: Date(timeIntervalSince1970: 1_000),
            odometerKilometers: nil,
            speedKilometersPerHour: nil
        ) != nil)
    }

    @Test("Pauses and resumes the existing trip")
    func pausesAndResumes() {
        let date = Date(timeIntervalSince1970: 1_000)
        var recorder = CurrentTripRecorder(applicationSessionID: UUID())
        _ = recorder.record(
            runState: .on,
            at: date,
            odometerKilometers: 100,
            speedKilometersPerHour: 10
        )

        let paused = recorder.pause(
            at: date.addingTimeInterval(30),
            odometerKilometers: 101,
            speedKilometersPerHour: 20
        )
        let resumed = recorder.resume(
            at: date.addingTimeInterval(90),
            odometerKilometers: 103,
            speedKilometersPerHour: 20
        )

        #expect(paused?.isPaused == true)
        #expect(resumed?.isPaused == false)
        #expect(resumed?.id == paused?.id)
        #expect(resumed?.elapsedSeconds == 30)
        #expect(resumed?.distanceKilometers == 1)
    }

    @Test("Restoring no trip clears previously restored state")
    func restoringNilClearsTrip() {
        let sessionID = UUID()
        var recorder = CurrentTripRecorder(applicationSessionID: sessionID)
        _ = recorder.record(
            runState: .on,
            at: Date(timeIntervalSince1970: 1_000),
            odometerKilometers: 100,
            speedKilometersPerHour: 8
        )

        recorder.restore(nil)

        #expect(recorder.trip == nil)
    }
}

private extension CurrentTripRecorder {
    init(applicationSessionID: UUID) {
        self.init(context: .init(
            applicationSessionID: applicationSessionID,
            vehicleIdentity: .temporary(UUID())
        ))
    }
}
