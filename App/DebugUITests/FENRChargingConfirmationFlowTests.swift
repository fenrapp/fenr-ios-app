import XCTest

@MainActor
final class FENRChargingConfirmationFlowTests: FENRUITestCase {
    func testChargingPowerAndTargetAreConfirmedAndPreserveSiblingValues() throws {
        launch(arguments: ["-debugScenario", "charging"])
        waitFor(element("dashboard.charging.power"))
        openSettings()
        tap("settings.diagnostics")
        tap("diagnostics.batteryHealth.open")
        tap("batteryHealth.charging")

        let power = app.sliders["batteryHealth.charging.power"]
        scrollTo(power)
        waitForEnabled(power)
        let target = app.sliders["batteryHealth.charging.target"]
        waitFor(target)
        let initialTarget = try XCTUnwrap(target.value as? String)
        XCTAssertFalse(initialTarget.isEmpty)
        power.adjust(toNormalizedSliderPosition: 0.75)
        let status = element("batteryHealth.charging.status")
        waitForValue(status, containing: "Confirmed")
        XCTAssertTrue(status.label.hasSuffix(" W"))
        let confirmedPower = String(status.label.dropFirst("Confirmed ".count))
        let watts = try XCTUnwrap(Int(confirmedPower
            .replacingOccurrences(of: " W", with: "")
            .replacingOccurrences(of: ",", with: "")))
        XCTAssertEqual(target.value as? String, initialTarget)
        capture("Charge power confirmed by the emulator")

        scrollTo(target)
        waitForEnabled(target)
        target.adjust(toNormalizedSliderPosition: 0.55)
        let targetConfirmed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", "Confirmed ", "%"),
            object: status
        )
        XCTAssertEqual(XCTWaiter.wait(for: [targetConfirmed], timeout: 10), .completed)
        let confirmedTarget = String(status.label.dropFirst("Confirmed ".count))
        let powerValue = app.staticTexts["batteryHealth.charging.power.value"]
        XCTAssertEqual(powerValue.label, "\(watts) W")
        capture("Charge target confirmed with power retained")

        goBack()
        goBack()
        goBack()
        goBack()
        waitFor(element("dashboard.charging.power"))
        let dashboardPower = String(format: "%.1f kW", Double(watts) / 1_000)
        XCTAssertTrue(element("dashboard.charging.power").staticTexts[dashboardPower].exists)
        XCTAssertTrue(element("dashboard.charging.target").staticTexts[confirmedTarget].exists)
    }

    private func waitForEnabled(_ control: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND enabled == true"), object: control
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
}
