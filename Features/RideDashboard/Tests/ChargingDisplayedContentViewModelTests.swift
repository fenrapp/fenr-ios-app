import Observation
@testable import RideDashboard
import Testing
import TestSupport

@MainActor
struct ChargingDisplayedContentViewModelTests {
    @Test("Invisible metric changes do not publish, while the next visible change does")
    func invisiblePrecisionDoesNotNotify() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(recorder: recorder, session: session)
        fixture.model.start()
        defer { fixture.model.stop() }
        await session.send(ChargingDisplayedContentFixtures.snapshot(temperature: 35.01))
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        let previous = fixture.model.viewState
        withObservationTracking {
            _ = fixture.model.viewState
        } onChange: {
            recorder.record("publication")
        }

        await session.send(ChargingDisplayedContentFixtures.snapshot(
            temperature: 35.02, vin: DashboardMappingSnapshots.otherVIN
        ))
        try #require(await waitUntil { recorder.count("chargingMapper") == 2 })
        #expect(fixture.model.viewState == previous)
        #expect(recorder.count("publication") == 0)
        await session.send(ChargingDisplayedContentFixtures.snapshot(
            temperature: 36.03, vin: DashboardMappingSnapshots.otherVIN
        ))
        try #require(await waitUntil { fixture.model.viewState.batteryTemperature.animationValue == 36.03 })
        #expect(fixture.model.viewState.batteryTemperature.valueText != previous.batteryTemperature.valueText)
        #expect(recorder.count("publication") == 1)
        await fixture.control.stopAndWait()
    }

    @Test("A temperature warning publishes even when the rounded temperature text is unchanged")
    func thresholdStillPublishes() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(recorder: recorder, session: session)
        fixture.model.start()
        defer { fixture.model.stop() }
        await session.send(ChargingDisplayedContentFixtures.snapshot(temperature: 49.99))
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        let previousText = fixture.model.viewState.batteryTemperature.valueText
        #expect(fixture.model.viewState.batteryTemperatureEmphasis == .normal)
        await session.send(ChargingDisplayedContentFixtures.snapshot(temperature: 50.01))
        try #require(await waitUntil { fixture.model.viewState.batteryTemperatureEmphasis == .warning })
        #expect(fixture.model.viewState.batteryTemperature.valueText == previousText)
        await fixture.control.stopAndWait()
    }

    @Test("Control transitions use the latest unrounded mapped snapshot and still require telemetry confirmation")
    func controlUsesLatestCachedSnapshot() async throws {
        let recorder = DashboardMapperCallRecorder()
        let session = ChargingDashboardVehicleSession()
        let fixture = DashboardMappingTestFactory.charging(recorder: recorder, session: session)
        fixture.model.start()
        defer { fixture.model.stop() }
        await session.send(ChargingDisplayedContentFixtures.snapshot(temperature: 35.01))
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        await session.send(ChargingDisplayedContentFixtures.snapshot(
            temperature: 35.02, vin: DashboardMappingSnapshots.otherVIN
        ))
        try #require(await waitUntil { recorder.count("chargingMapper") == 2 })
        fixture.model.setChargePowerLimit(watts: 1_500)
        try #require(await waitUntil {
            fixture.control.state.status == .confirming(.powerWatts(1_500))
                && fixture.model.viewState.control.power.selected == 1_500
        })
        #expect(fixture.model.viewState.batteryTemperature.animationValue == 35.02)
        #expect(!fixture.model.viewState.control.isEnabled)
        #expect(fixture.model.viewState.control.target.selected == 100)
        await session.send(ChargingDisplayedContentFixtures.snapshot(
            temperature: 35.02, vin: DashboardMappingSnapshots.otherVIN, watts: 1_500
        ))
        try #require(await waitUntil {
            fixture.control.state.status == .confirmed(.powerWatts(1_500))
                && fixture.model.viewState.control.isEnabled
        })
        #expect(await fixture.repository.powerWrites == [1_500])
        #expect(await fixture.repository.targetWrites.isEmpty)
        await fixture.control.stopAndWait()
    }
}
