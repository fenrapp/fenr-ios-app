import XCTest

@MainActor
class FENRUITestCase: XCTestCase {
    let app = XCUIApplication()
    let sessionID = UUID().uuidString
    private var additionalArguments: [String] = []

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            capture("Failure")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Failure accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    func launch(reset: Bool = true, arguments: [String] = []) {
        continueAfterFailure = false
        additionalArguments = arguments
        let scenario = arguments.contains("-debugScenario") ? [] : ["-debugScenario", "charging"]
        app.launchArguments = [
            "-uiTesting", "-uiTestSession", sessionID, "-skipOnboarding",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ] + (reset ? ["-uiTestReset"] : []) + scenario + arguments
        XCUIDevice.shared.orientation = .landscapeRight
        app.launch()
        if let index = app.launchArguments.firstIndex(of: "-debugScenario") {
            let marker = app.launchArguments[index + 1] == "charging"
                ? "dashboard.charging.power" : "dashboard.cards"
            waitFor(element(marker))
        }
    }

    func relaunch() {
        app.terminate()
        launch(reset: false, arguments: additionalArguments)
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func waitFor(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing: \(element)", file: file, line: line)
    }

    func waitForAbsence(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, file: file, line: line)
    }

    func waitForValue(
        _ element: XCUIElement,
        containing value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", value, value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed, file: file, line: line)
    }

    func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        _ = target.waitForExistence(timeout: 2)
        if identifier.hasPrefix("dashboard."), element("dashboard.cards").exists,
           !target.exists || !app.frame.contains(target.frame) {
            app.revealDashboardCard(identifier, file: file, line: line)
        }
        scrollTo(target, file: file, line: line)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true AND enabled == true"), object: target
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed, file: file, line: line)
        target.tap()
    }

    func scrollTo(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0 ..< 8 where !target.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(target.isHittable, "Not hittable: \(target)", file: file, line: line)
    }

    func replaceText(_ target: XCUIElement, with text: String, keyboardAccessory: String? = nil) {
        _ = target.waitForExistence(timeout: 2)
        scrollTo(target)
        target.tap()
        revealFocusedField(target, keyboardAccessory: keyboardAccessory)
        if let current = target.value as? String, !current.isEmpty, current != target.placeholderValue {
            let trailingPoint = target.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            trailingPoint.tap()
            trailingPoint.tap()
            let menuItem = app.menuItems["Select All"].firstMatch
            let selectAll = menuItem.waitForExistence(timeout: 2) ? menuItem : app.buttons["Select All"].firstMatch
            waitFor(selectAll)
            selectAll.tap()
            target.typeText(XCUIKeyboardKey.delete.rawValue)
            let cleared = XCTNSPredicateExpectation(
                predicate: NSPredicate(
                    format: "value == '' OR value == %@", target.placeholderValue ?? ""
                ), object: target
            )
            XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 10), .completed)
        }
        target.typeText(text)
        let replaced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", text), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [replaced], timeout: 10), .completed)
    }

    private func revealFocusedField(_ target: XCUIElement, keyboardAccessory: String?) {
        waitFor(app.keyboards.firstMatch)
        guard let keyboardAccessory else { return }
        let accessory = element(keyboardAccessory)
        waitFor(accessory)
        for _ in 0 ..< 8 {
            let accessoryTop = accessory.frame.minY
            guard target.frame.maxY < accessoryTop else {
                let start = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.width / 2, dy: accessoryTop - app.frame.minY - 16))
                let end = start.withOffset(CGVector(dx: 0, dy: -120))
                start.press(forDuration: 0.1, thenDragTo: end)
                continue
            }
            return
        }
        XCTFail("Focused field remains covered by the keyboard toolbar: \(target)")
    }

    func dismissKeyboard(using identifier: String) {
        guard app.keyboards.firstMatch.exists else { return }
        tap(identifier)
        waitForAbsence(app.keyboards.firstMatch)
    }

    func openSettings() {
        tap("dashboard.settings")
        waitFor(element("settings.rideDisplay"))
    }

    func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        waitFor(back)
        back.tap()
    }

    func setReadFailure(_ identifier: String, enabled: Bool) {
        tap("uiTesting.controls")
        let toggle = element(identifier)
        waitFor(toggle)
        let expected = enabled ? "1" : "0"
        if toggle.value as? String != expected {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        }
        waitForValue(toggle, containing: expected)
        tap("uiTesting.controls.close")
    }

    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
