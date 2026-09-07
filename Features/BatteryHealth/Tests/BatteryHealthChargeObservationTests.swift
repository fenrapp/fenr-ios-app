@testable import BatteryHealth
@testable import ChargeControl
import Testing
import TestSupport

@MainActor
struct BatteryHealthChargeObservationTests {
    @Test("Battery Health replays busy and failure state while stopped consumers remain detached")
    func replayAndRestartPreserveCurrentChargeState() async throws {
        let fixture = BatteryChargeObservationFixture.make()
        defer { fixture.model.stop() }
        fixture.control.setPowerLimit(watts: 2_000)
        fixture.model.start()
        fixture.model.start()
        #expect(fixture.emitter.subscriberCount == 1)
        try #require(await waitUntil {
            fixture.model.viewState.chargingDetail.control.power.selected == 2_000
                && !fixture.model.viewState.chargingDetail.control.isEnabled
        })
        await fixture.model.stopAndWait()
        try #require(await waitUntil { fixture.emitter.subscriberCount == 0 })
        let stoppedState = fixture.model.viewState

        fixture.control.receive(.init())
        await fixture.repository.failNextChargePreparation()
        fixture.control.receive(BatteryObservationData.chargingHealth)
        try #require(await waitUntil { fixture.control.state.failure == .preparationFailed })
        #expect(fixture.model.viewState == stoppedState)

        fixture.model.start()
        fixture.model.start()
        #expect(fixture.emitter.subscriberCount == 1)
        try #require(await waitUntil { fixture.model.viewState.chargingDetail.control.errorText != nil })
        #expect(fixture.model.viewState.chargingDetail.control.statusIsError)
        await fixture.model.stopAndWait()
        await fixture.control.stopAndWait()
        #expect(await waitUntil { fixture.emitter.subscriberCount == 0 })
    }
}
