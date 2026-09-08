@testable import RideNavigation
import Testing
import TestSupport

@MainActor
struct RideNavigationActivityLifecycleTests {
    @Test("An old non-cooperative clock cannot publish into the restarted lifecycle")
    func restartedClockRejectsOldTick() async throws {
        let clock = ActivityControllerTestClock()
        let fixture = ActivityControllerTestFixture.make(timing: clock.makeTiming())
        defer {
            fixture.stop()
            clock.resumeAll()
        }
        fixture.start()
        _ = fixture.activity.startRecording(name: "Recording")
        try #require(await waitUntil { clock.pendingSleepCount(for: .seconds(1)) == 1 })
        let oldClock = fixture.activity.clockTask
        fixture.activity.stop()
        fixture.activity.start()
        let newClock = fixture.activity.clockTask
        let recorder = ActivityControllerUpdateRecorder(stream: fixture.activity.observe())
        recorder.start()
        try #require(await waitUntil {
            clock.pendingSleepCount(for: .seconds(1)) == 2 && recorder.updates.count == 1
        })
        clock.advance(seconds: 1)
        clock.resumeFirstSleep(for: .seconds(1))
        await oldClock?.value
        clock.advance(seconds: 1)
        clock.resumeFirstSleep(for: .seconds(1))
        try #require(await waitUntil { recorder.updates.last?.snapshot.elapsedSeconds == 2 })
        #expect(recorder.updates.count == 2)
        fixture.stop()
        clock.resumeAll()
        await newClock?.value
        #expect(await waitUntil { recorder.isFinished })
        recorder.stop()
    }

    @Test("Stop cancels queued voice and feedback while the restarted lifecycle can use both")
    func restartCancelsOldVoiceAndFeedback() async {
        let timing = ControllableRideNavigationTiming()
        let fixture = ActivityControllerTestFixture.make(timing: timing.makeTiming())
        fixture.start()
        fixture.activity.announce("Old announcement")
        fixture.activity.notifySuccess()
        let oldVoice = fixture.activity.voiceAnnouncementTask
        let oldFeedback = fixture.activity.feedbackTask
        fixture.activity.stop()
        fixture.activity.start()
        fixture.activity.announce("Current announcement")
        fixture.activity.notifySuccess()
        await oldVoice?.value
        await oldFeedback?.value
        await fixture.activity.voiceAnnouncementTask?.value
        await fixture.activity.feedbackTask?.value
        #expect(await fixture.guidance.recordedAnnouncements() == ["Current announcement"])
        #expect(await fixture.guidance.recordedSuccessCount() == 1)
        fixture.stop()
    }

    @Test("A stopped trail preparation cannot replace a restarted trail", arguments: [false, true])
    func restartRejectsOldTrailPreparation(oldSucceeds: Bool) async throws {
        let timing = ControllableRideNavigationTiming()
        let preparer = ActivityControllerTrailMapPreparer()
        let fixture = ActivityControllerTestFixture.make(timing: timing.makeTiming(), trailMapPreparer: preparer)
        defer {
            fixture.stop()
            preparer.finish()
        }
        let first = ActivityControllerTestData.trailRoute(name: "Old trail", finishIndex: 5)
        let second = ActivityControllerTestData.trailRoute(name: "Current trail", finishIndex: 9)
        let firstPlan = try #require(await ActivityControllerTestFixture.prepareMap(route: first))
        let secondPlan = try #require(await ActivityControllerTestFixture.prepareMap(route: second))
        fixture.start()
        fixture.planning.selectTrailRoute(first)
        fixture.activity.prepareTrailPreview()
        let oldPreparation = fixture.activity.trailPreparationTask
        try #require(await waitUntil { preparer.hasRequest(routeID: first.id) })
        fixture.activity.stop()
        fixture.activity.start()
        fixture.planning.selectTrailRoute(second)
        fixture.activity.prepareTrailPreview()
        let newPreparation = fixture.activity.trailPreparationTask
        try #require(await waitUntil { preparer.hasRequest(routeID: second.id) })
        preparer.complete(routeID: second.id, plan: secondPlan)
        await newPreparation?.value
        let expectedCoordinates = fixture.activity.snapshot.trailOverviewCoordinates
        #expect(!expectedCoordinates.isEmpty)
        preparer.complete(routeID: first.id, plan: oldSucceeds ? firstPlan : nil)
        await oldPreparation?.value
        #expect(fixture.activity.snapshot.trailOverviewCoordinates == expectedCoordinates)
        #expect(fixture.activity.snapshot.trailGuidance.routeID == second.id)
        #expect(fixture.activity.snapshot.errorMessage == nil)
        fixture.stop()
    }
}
