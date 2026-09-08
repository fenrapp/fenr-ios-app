@testable import ChargeControl
@testable import RideDashboard
import Testing
import TestSupport

@MainActor
struct ChargingDashboardObservationTests {
    @Test("Charging updates busy controls and restarts with the current failure without duplicate subscriptions")
    func observesLiveChangesAndReplaysAfterRestart() async throws {
        let fixture = ChargingObservationFixture.make()
        defer { fixture.model.stop() }
        fixture.model.start()
        fixture.model.start()
        #expect(fixture.emitter.subscriberCount == 1)
        try #require(await waitUntil { fixture.model.viewState.control.isEnabled })
        fixture.control.setPowerLimit(watts: 2_000)
        try #require(await waitUntil {
            fixture.model.viewState.control.power.selected == 2_000
                && !fixture.model.viewState.control.isEnabled
        })

        fixture.model.suspend()
        try #require(await waitUntil { fixture.emitter.subscriberCount == 0 })
        let suspendedState = fixture.model.viewState
        await fixture.repository.failNextChargePreparation()
        fixture.control.receive(ChargingObservationData.chargingHealth)
        try #require(await waitUntil { fixture.control.state.failure == .preparationFailed })
        #expect(fixture.model.viewState == suspendedState)

        fixture.model.start()
        fixture.model.start()
        #expect(fixture.emitter.subscriberCount == 1)
        try #require(await waitUntil { fixture.model.viewState.control.status?.emphasis == .failure })
        #expect(!fixture.model.viewState.control.isEnabled)
        fixture.model.stop()
        await fixture.control.stopAndWait()
        #expect(await waitUntil { fixture.emitter.subscriberCount == 0 })
    }
}
