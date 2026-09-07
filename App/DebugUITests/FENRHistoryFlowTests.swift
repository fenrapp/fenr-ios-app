import XCTest

@MainActor
final class FENRHistoryFlowTests: FENRUITestCase {
    func testHistoryAndDetailRecoverFromReadFailures() {
        launch()
        setReadFailure("uiTesting.historyReadFailure", enabled: true)
        openSettings()
        tap("settings.rideHistory")
        waitFor(element("rideHistory.retry"))
        XCTAssertFalse(element("rideHistory.row").exists)
        capture("History read failure")

        setReadFailure("uiTesting.historyReadFailure", enabled: false)
        tap("rideHistory.retry")
        waitFor(element("rideHistory.row"))
        waitForAbsence(element("rideHistory.retry"))

        setReadFailure("uiTesting.historyReadFailure", enabled: true)
        tap("rideHistory.row")
        waitFor(element("rideHistory.detail.retry"))
        XCTAssertFalse(element("rideHistory.detail.loaded").exists)
        setReadFailure("uiTesting.historyReadFailure", enabled: false)
        tap("rideHistory.detail.retry")
        waitFor(element("rideHistory.detail.loaded"))
        waitForAbsence(element("rideHistory.detail.retry"))
        scrollTo(app.staticTexts["Distance"])
        XCTAssertTrue(app.staticTexts["Distance"].exists)
        capture("Recovered ride detail")
    }
}
