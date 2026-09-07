import XCTest

@MainActor
final class FENRMaintenanceFlowTests: FENRUITestCase {
    func testMaintenanceRetryCreateEditRelaunchAndDelete() {
        launch()
        setReadFailure("uiTesting.maintenanceReadFailure", enabled: true)
        openSettings()
        tap("settings.maintenance")
        waitFor(element("maintenance.retry"))
        XCTAssertFalse(element("maintenance.row").exists)
        XCTAssertFalse(element("maintenance.add").isEnabled)
        setReadFailure("uiTesting.maintenanceReadFailure", enabled: false)
        tap("maintenance.retry")
        waitForAbsence(element("maintenance.retry"))

        tap("maintenance.add")
        replaceMaintenanceText("maintenance.workshop", with: "FENR QA Workshop")
        dismissKeyboard(using: "maintenance.keyboard.done")
        replaceMaintenanceText("maintenance.notes", with: "Chain inspected")
        dismissKeyboard(using: "maintenance.keyboard.done")
        tap("maintenance.save")
        waitFor(element("maintenance.row"))
        tap("maintenance.row")
        assertDetailField("notes", label: "Notes", value: "Chain inspected")
        tap("maintenance.edit")
        scrollTo(element("maintenance.workshop"))
        waitForValue(element("maintenance.workshop"), containing: "FENR QA Workshop")
        replaceMaintenanceText("maintenance.notes", with: "Chain inspected and adjusted")
        dismissKeyboard(using: "maintenance.keyboard.done")
        tap("maintenance.save")
        assertDetailField("notes", label: "Notes", value: "Chain inspected and adjusted")

        relaunch()
        openSettings()
        tap("settings.maintenance")
        waitFor(element("maintenance.row"))
        XCTAssertEqual(app.buttons.matching(identifier: "maintenance.row").count, 1)
        tap("maintenance.row")
        assertDetailField("workshop", label: "Workshop", value: "FENR QA Workshop")
        assertDetailField("notes", label: "Notes", value: "Chain inspected and adjusted")
        capture("Persisted maintenance edit")
        tap("maintenance.delete.open")
        tap("maintenance.delete.confirm")
        waitForAbsence(element("maintenance.row"))
        waitFor(element("maintenance.add"))

        relaunch()
        openSettings()
        tap("settings.maintenance")
        waitFor(app.staticTexts["No Maintenance Yet"])
        XCTAssertFalse(element("maintenance.row").exists)
    }

    private func replaceMaintenanceText(_ identifier: String, with text: String) {
        replaceText(element(identifier), with: text, keyboardAccessory: "maintenance.keyboard.done")
    }

    private func assertDetailField(_ id: String, label: String, value: String) {
        let field = element("maintenance.detail.\(id)")
        scrollTo(field)
        let exact = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "value == %@ OR label == %@ OR label == %@", value, value, "\(label), \(value)"
            ), object: field
        )
        XCTAssertEqual(XCTWaiter.wait(for: [exact], timeout: 10), .completed)
    }
}
