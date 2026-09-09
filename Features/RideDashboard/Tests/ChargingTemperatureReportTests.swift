import BikeDomain
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@MainActor
struct ChargingTemperatureReportTests {
    @Test("Temperature severity does not change the selected metric unit")
    func metricUnitIsStableAcrossTemperatureBands() {
        for locale in ["fr_FR", "es_ES", "en_US"] {
            for celsius in [0.0, 3.9, 23, 50, 60, 100] {
                let state = ChargingTemperatureReportTestFactory.state(
                    temperatures: [celsius], units: .metric, locale: locale
                )
                #expect(state.batteryTemperature.unitText == "°C")
            }
        }
    }

    @Test("Fahrenheit formatting and thermal severity are independent")
    func fahrenheitDoesNotCauseCriticalEmphasis() {
        let normal = ChargingTemperatureReportTestFactory.state(temperatures: [23], units: .imperial)
        #expect(normal.batteryTemperature.valueText == "73")
        #expect(normal.batteryTemperature.unitText == "°F")
        #expect(normal.batteryTemperatureEmphasis == .normal)
        let cold = ChargingTemperatureReportTestFactory.state(temperatures: [0], units: .imperial)
        #expect(cold.batteryTemperature.valueText == "32")
        #expect(cold.batteryTemperature.unitText == "°F")
        #expect(cold.batteryTemperatureEmphasis == .critical)
    }

    @Test("System units follow the region while explicit metric overrides a US region")
    func systemUnitsFollowRegion() {
        let french = ChargingTemperatureReportTestFactory.state(temperatures: [23], units: .system, locale: "fr_FR")
        let american = ChargingTemperatureReportTestFactory.state(temperatures: [23], units: .system, locale: "en_US")
        #expect(french.batteryTemperature.unitText == "°C")
        #expect(american.batteryTemperature.unitText == "°F")
        #expect(french.batteryTemperatureEmphasis == american.batteryTemperatureEmphasis)
    }

    @Test("Synthetic zero-filled sensor slots can produce a cold critical average without changing units")
    func zeroFilledSlotsReproduceCriticalAverage() {
        let normal = ChargingTemperatureReportTestFactory.state(
            temperatures: ChargingTemperatureReportFixtures.normal, units: .metric
        )
        let sparse = ChargingTemperatureReportTestFactory.state(
            temperatures: ChargingTemperatureReportFixtures.zeroFilled, units: .metric
        )
        #expect(normal.batteryTemperature.valueText == "23")
        #expect(normal.batteryTemperatureEmphasis == .normal)
        #expect(sparse.batteryTemperature.valueText == "4")
        #expect(sparse.batteryTemperature.unitText == "°C")
        #expect(sparse.batteryTemperatureEmphasis == .critical)
    }

    @Test("No temperature samples produce unavailable data instead of a critical zero")
    func missingSamplesAreUnavailable() {
        let state = ChargingTemperatureReportTestFactory.state(temperatures: [], units: .metric)
        #expect(state.batteryTemperature.unitText == nil)
        #expect(state.batteryTemperatureEmphasis == .unavailable)
    }

    @Test("Suspend and resume preserve metric units until the settings explicitly change")
    func connectionCycleDoesNotSwitchUnits() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(recorder: recorder, session: session)
        fixture.model.start()
        defer { fixture.model.stop() }
        await session.send(ChargingTemperatureReportFixtures.snapshot(units: .metric))
        try #require(await waitUntil { fixture.model.viewState.batteryTemperature.unitText == "°C" })
        fixture.model.suspend()
        #expect(fixture.model.viewState.batteryTemperature.unitText == "°C")
        fixture.model.start()
        await session.send(ChargingTemperatureReportFixtures.snapshot(units: .metric))
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        #expect(fixture.model.viewState.batteryTemperature.unitText == "°C")
        await session.send(ChargingTemperatureReportFixtures.snapshot(units: .imperial))
        try #require(await waitUntil { fixture.model.viewState.batteryTemperature.unitText == "°F" })
        fixture.model.stop()
        await fixture.control.stopAndWait()
    }

    @Test("Telemetry arriving before saved settings can temporarily display US system units")
    func telemetryBeforeSettingsDisplaysSystemUnits() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(
            recorder: recorder, session: session, locale: .init(identifier: "en_US")
        )
        fixture.model.start()
        defer { fixture.model.stop() }
        await session.send(ChargingTemperatureReportFixtures.snapshot(units: .system, hasReceivedSettings: false))
        try #require(await waitUntil { fixture.model.viewState.batteryTemperature.unitText == "°F" })
        #expect(fixture.model.viewState.batteryTemperature.valueText == "73")
        #expect(fixture.model.viewState.batteryTemperatureEmphasis == .normal)
        await session.send(ChargingTemperatureReportFixtures.snapshot(units: .metric))
        try #require(await waitUntil { fixture.model.viewState.batteryTemperature.unitText == "°C" })
        #expect(fixture.model.viewState.batteryTemperature.valueText == "23")
        fixture.model.stop()
        await fixture.control.stopAndWait()
    }
}
