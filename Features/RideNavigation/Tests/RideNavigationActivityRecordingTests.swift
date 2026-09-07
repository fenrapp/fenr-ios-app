@testable import RideNavigation
import Testing

@MainActor
struct RideNavigationActivityRecordingTests {
    @Test("Pausing and changing mini presentation retain recorded points and exclude paused movement")
    func recordingRetainsSegmentsAcrossPauseAndMini() async throws {
        let clock = ActivityControllerTestClock()
        let fixture = ActivityControllerTestFixture.make(timing: clock.makeTiming())
        defer {
            fixture.stop()
            clock.resumeAll()
        }
        fixture.start()
        _ = fixture.activity.startRecording(name: "Recorded ride")
        let firstClock = fixture.activity.clockTask
        fixture.receive(index: 0, seconds: 0)
        fixture.activity.setPresentationMode(.mini)
        clock.advance(seconds: 5)
        fixture.receive(index: 1, seconds: 5)
        fixture.activity.toggleRecordingPause()
        clock.advance(seconds: 50)
        fixture.receive(index: 9, seconds: 55)
        fixture.activity.toggleRecordingPause()
        fixture.receive(index: 2, seconds: 55)
        fixture.activity.setPresentationMode(.fullScreen)
        let restartedClock = fixture.activity.clockTask
        clock.advance(seconds: 5)
        fixture.receive(index: 3, seconds: 60)
        _ = fixture.activity.finishActivity()
        let completed = try #require(fixture.activity.snapshot.completedRecording)
        #expect(completed.segments.map { $0.points.map(\.coordinate) } == [
            [ActivityControllerTestData.coordinate(index: 0), ActivityControllerTestData.coordinate(index: 1)],
            [ActivityControllerTestData.coordinate(index: 2), ActivityControllerTestData.coordinate(index: 3)]
        ])
        #expect(fixture.activity.snapshot.completion?.elapsedSeconds == 10)
        #expect(fixture.activity.snapshot.completion?.isSuccessful == true)
        #expect(fixture.activity.snapshot.activity == .preview)
        fixture.stop()
        clock.resumeAll()
        await firstClock?.value
        await restartedClock?.value
        await fixture.library.draftTask?.value
    }
}
