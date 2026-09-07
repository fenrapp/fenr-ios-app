import XCTest

@MainActor
class FENRNavigationUITestCase: FENRUITestCase {
    func startRecording() {
        tap("dashboard.navigation.open")
        tap("rideNavigation.record")
        waitFor(element("rideNavigation.pause"))
        advanceGPS()
        let initial = progressDistance
        advanceGPS(count: 9)
        waitForDistanceChange(from: initial)
    }

    func advanceGPS(count: Int = 1) {
        tap("uiTesting.controls")
        let advance = element("uitest.navigation.advanceGPS")
        waitFor(advance)
        for _ in 0 ..< count { advance.tap() }
        tap("uiTesting.controls.close")
    }

    func armSaveFailure() {
        tap("uiTesting.controls")
        tap("uitest.navigation.failNextSave")
        tap("uiTesting.controls.close")
    }

    var progressDistance: String {
        element("rideNavigation.progress").label.components(separatedBy: " \u{00b7} ")[0]
    }

    func waitForDistanceChange(from previous: String) {
        let progress = element("rideNavigation.progress")
        XCTAssertFalse(previous.isEmpty)
        let predicate = NSPredicate(format: "exists == true AND NOT (label BEGINSWITH %@)", previous + " \u{00b7} ")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }

    func finishRecording(name: String) {
        tap("rideNavigation.finish")
        tap("rideNavigation.finish.confirm")
        let field = element("rideNavigation.summary.name")
        waitFor(field)
        replaceText(field, with: name)
        field.typeText("\n")
    }

    func assertSingleSavedRoute(named name: String) {
        let rows = app.buttons.matching(identifier: "rideNavigation.savedRoute")
        waitFor(rows.firstMatch)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.firstMatch.label.contains(name))
        waitForValue(element("rideNavigation.savedRoute.count"), containing: "1")
    }
}
