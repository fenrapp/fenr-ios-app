import XCTest

@MainActor
final class FENRSettingsFlowTests: FENRUITestCase {
    func testIndependentSettingsSurviveNavigationAndRelaunch() {
        launch()
        openSettings()
        tap("settings.measurementUnits")
        app.buttons["Imperial"].tap()
        waitForValue(element("settings.measurementUnits"), containing: "Imperial")

        goBack()
        openSettings()
        tap("settings.rideDisplay")
        tap("settings.phoneBattery")
        app.buttons["Hidden"].tap()
        waitForValue(element("settings.phoneBattery"), containing: "Hidden")
        goBack()
        goBack()
        waitForAbsence(element("dashboard.phone-battery"))

        relaunch()
        openSettings()
        scrollTo(element("settings.measurementUnits"))
        waitForValue(element("settings.measurementUnits"), containing: "Imperial")
        goBack()
        openSettings()
        tap("settings.rideDisplay")
        waitForValue(element("settings.phoneBattery"), containing: "Hidden")
        capture("Persisted independent settings")
    }
}
