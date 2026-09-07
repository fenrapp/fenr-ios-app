import XCTest

@MainActor
final class FENRNavigationSaveRecoveryFlowTests: FENRNavigationUITestCase {
    func testFailedSaveRetainsSummaryAndNameThenRetryPersistsExactlyOneRoute() {
        launch(arguments: ["-debugScenario", "riding"])
        startRecording()
        finishRecording(name: "Retry recording")
        let summary = element("rideNavigation.summary.detail").label
        armSaveFailure()
        tap("rideNavigation.summary.save")
        waitFor(element("rideNavigation.summary.retrySave"))
        XCTAssertEqual(element("rideNavigation.summary.name").value as? String, "Retry recording")
        XCTAssertEqual(element("rideNavigation.summary.detail").label, summary)
        XCTAssertFalse(element("rideNavigation.savedRoute").exists)
        capture("Save failure preserves the completed recording")

        tap("rideNavigation.summary.retrySave")
        waitForAbsence(element("rideNavigation.summary.name"))
        assertSingleSavedRoute(named: "Retry recording")
        relaunch()
        tap("dashboard.navigation.open")
        assertSingleSavedRoute(named: "Retry recording")
        capture("One saved route after retry and relaunch")
    }
}
