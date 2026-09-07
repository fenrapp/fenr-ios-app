import XCTest

@MainActor
final class FENRNavigationRecordingFlowTests: FENRNavigationUITestCase {
    func testRecordingPauseResumeMiniSaveAndRelaunch() {
        launch(arguments: ["-debugScenario", "riding"])
        startRecording()
        tap("rideNavigation.pause")
        waitFor(element("rideNavigation.resume"))
        let paused = element("rideNavigation.progress").label
        let pausedDistance = progressDistance
        advanceGPS(count: 9)
        XCTAssertEqual(element("rideNavigation.progress").label, paused)

        tap("rideNavigation.resume")
        advanceGPS(count: 9)
        waitForDistanceChange(from: pausedDistance)
        let beforeMini = progressDistance
        tap("rideNavigation.minimize")
        waitFor(element("rideNavigation.miniMap"))
        advanceGPS(count: 9)
        capture("Recording continues in mini navigation")
        tap("rideNavigation.miniMap")
        waitFor(element("rideNavigation.pause"))
        waitForDistanceChange(from: beforeMini)

        finishRecording(name: "UI recording")
        capture("Completed recording summary")
        tap("rideNavigation.summary.save")
        waitForAbsence(element("rideNavigation.summary.name"))
        assertSingleSavedRoute(named: "UI recording")
        relaunch()
        tap("dashboard.navigation.open")
        assertSingleSavedRoute(named: "UI recording")
        capture("Saved recording after relaunch")
    }
}
