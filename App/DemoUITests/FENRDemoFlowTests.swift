import XCTest

@MainActor
final class FENRDemoFlowTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testPublicDemoReturnsToOnboarding() throws {
        app.launch()
        try tap("onboarding.exploreDemo")
        try revealAndTap("demo.start")
        try waitFor(app.windows.firstMatch, predicate: NSPredicate { candidate, _ in
            guard let window = candidate as? XCUIElement else { return false }
            return window.frame.width > window.frame.height
        })
        try tap("demo.openControls")
        let riding = app.buttons["demo.scenario.riding"]
        try tap("demo.scenario.riding")
        try waitFor(riding, predicate: NSPredicate(format: "selected == true"))
        try tap("demo.done")
        try waitFor(app.buttons["dashboard.settings"].firstMatch)
        capture("Public demo dashboard")
        app.revealDashboardCard("dashboard.settings")
        try tap("dashboard.settings")
        try revealAndTap("settings.changeBike")
        try waitFor(app.buttons["onboarding.exploreDemo"])
        XCTAssertFalse(app.buttons["demo.openControls"].exists)
        capture("Returned to onboarding")
        app.terminate()
        app.launch()
        try waitFor(app.buttons["onboarding.exploreDemo"])
    }

    private func tap(_ identifier: String) throws {
        let button = app.buttons[identifier].firstMatch
        try waitFor(button, predicate: NSPredicate { candidate, _ in
            guard let element = candidate as? XCUIElement else { return false }
            return self.isReadyToTap(element)
        })
        button.tap()
    }

    private func revealAndTap(_ identifier: String) throws {
        let button = app.buttons[identifier].firstMatch
        for _ in 0 ..< 12 {
            if isReadyToTap(button) {
                button.tap()
                return
            }
            app.swipeUp()
        }
        try tap(identifier)
    }

    private func isReadyToTap(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite, !frame.isEmpty,
              app.windows.firstMatch.frame.contains(frame) else { return false }
        return element.isHittable
    }

    private func waitFor(
        _ element: XCUIElement,
        predicate: NSPredicate = NSPredicate(format: "exists == true")
    ) throws {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: 15)
        XCTAssertEqual(result, .completed, "Timed out waiting for \(element)")
        guard result == .completed else { throw DemoFlowError.timedOut }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private enum DemoFlowError: Error {
        case timedOut
    }
}
