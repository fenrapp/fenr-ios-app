import BikeDomain
import ChargeControl
import Foundation
import Testing
import TestSupport

@MainActor
struct ChargingPreferencesTests {
    @Test func offlineEditsPersistOnlyExplicitFieldsAndApplyOnConnection() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.connect(false)
        fixture.controller.setTarget(percent: 90)
        #expect(fixture.controller.state.preferences.pendingPower == nil)
        #expect(fixture.store.values["FENRTEST000000001"]?.pendingTarget?.percent == 90)
        #expect(await fixture.repository.writes.isEmpty)
        fixture.connect(true)
        #expect(await waitUntil { !fixture.controller.state.preferences.hasPendingChanges })
        #expect(await fixture.repository.writes == ["target:90"])
        #expect(fixture.controller.state.preferences.confirmed?.chargePowerWatts == 1_200)
        await fixture.controller.stopAndWait()
    }

    @Test func readsAndSelectingChargerNeverWrite() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.connect(true)
        #expect(await waitUntil { fixture.controller.state.hasFreshConfiguration })
        fixture.controller.selectCharger(.backpack)
        #expect(await fixture.repository.writes.isEmpty)
        #expect(!fixture.controller.state.preferences.hasPendingChanges)
        await fixture.controller.stopAndWait()
    }

    @Test func matchingValuesClearWithoutWriteAndTargetPrecedesPower() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.connect(false)
        fixture.controller.selectCharger(.standard)
        fixture.controller.setPower(watts: 1_200)
        fixture.controller.setTarget(percent: 80)
        fixture.connect(true)
        #expect(await waitUntil { !fixture.controller.state.preferences.hasPendingChanges })
        #expect(await fixture.repository.writes.isEmpty)
        fixture.connect(false)
        fixture.controller.setPower(watts: 2_000)
        fixture.controller.setTarget(percent: 95)
        fixture.connect(true)
        #expect(await waitUntil { !fixture.controller.state.preferences.hasPendingChanges })
        #expect(await fixture.repository.writes == ["target:95", "power:2000"])
        await fixture.controller.stopAndWait()
    }

    @Test func failedPersistencePreventsWritesAndUnreadableStoreIsNotOverwritten() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.store.failsLoad = true
        fixture.connect(false)
        fixture.controller.setTarget(percent: 90)
        #expect(fixture.controller.state.failure == .storage)
        #expect(fixture.store.values.isEmpty)
        fixture.store.failsLoad = false
        fixture.controller.retry()
        fixture.store.failsSave = true
        fixture.controller.setTarget(percent: 90)
        fixture.connect(true)
        #expect(await fixture.repository.writes.isEmpty)
        #expect(fixture.controller.state.preferences.pendingTarget == nil)
        await fixture.controller.stopAndWait()
    }

    @Test func partialFailureKeepsOnlyUnconfirmedFieldAndRetriesExplicitly() async {
        let fixture = ChargingPreferencesFixture.make()
        await fixture.repository.configure(failsPower: true)
        fixture.connect(false)
        fixture.controller.selectCharger(.standard)
        fixture.controller.setPower(watts: 2_000)
        fixture.controller.setTarget(percent: 90)
        fixture.connect(true)
        #expect(await waitUntil { fixture.controller.state.failure != nil })
        #expect(fixture.controller.state.preferences.pendingTarget == nil)
        #expect(fixture.controller.state.preferences.pendingPower?.watts == 2_000)
        fixture.connect(true)
        #expect(await fixture.repository.writes == ["target:90", "power:2000"])
        await fixture.repository.configure()
        fixture.controller.retry()
        #expect(await waitUntil { !fixture.controller.state.preferences.hasPendingChanges })
        await fixture.controller.stopAndWait()
    }

    @Test func unsupportedFirmwareAndMismatchKeepPending() async {
        let fixture = ChargingPreferencesFixture.make()
        await fixture.repository.configure(compatible: false)
        fixture.connect(false)
        fixture.controller.setTarget(percent: 90)
        fixture.connect(true)
        #expect(await waitUntil { fixture.controller.state.failure == .incompatibleFirmware })
        #expect(await fixture.repository.writes.isEmpty)
        await fixture.repository.configure(ignoresTarget: true)
        fixture.controller.retry()
        #expect(await waitUntil { fixture.controller.state.failure == .confirmation })
        #expect(fixture.controller.state.preferences.pendingTarget?.percent == 90)
        await fixture.controller.stopAndWait()
    }

    @Test func changingBikeIsolatesAndCancelDoesNotRevert() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.connect(false)
        fixture.controller.setTarget(percent: 90)
        fixture.connect(true, vin: "FENRTEST000000002")
        #expect(await waitUntil { fixture.controller.state.hasFreshConfiguration })
        #expect(await fixture.repository.writes.isEmpty)
        fixture.connect(false)
        #expect(fixture.controller.state.preferences.pendingTarget?.percent == 90)
        fixture.controller.cancelPending()
        fixture.connect(true)
        #expect(await waitUntil { fixture.controller.state.hasFreshConfiguration })
        #expect(await fixture.repository.writes.isEmpty)
        await fixture.controller.stopAndWait()
    }

    @Test func chargerMismatchDoesNotClampAndSelectionDoesNotRetarget() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.connect(false)
        fixture.controller.selectCharger(.fast)
        fixture.controller.setPower(watts: 7_000)
        fixture.controller.selectCharger(.standard)
        #expect(fixture.controller.state.preferences.pendingPower?.charger == .fast)
        fixture.connect(true, charger: .standard)
        #expect(await waitUntil { fixture.controller.state.failure == .chargerChanged })
        #expect(await fixture.repository.writes.isEmpty)
        #expect(fixture.controller.state.preferences.pendingPower?.watts == 7_000)
        await fixture.controller.stopAndWait()
    }

    @Test func newerRevisionSurvivesEarlierConfirmation() async {
        let fixture = ChargingPreferencesFixture.make()
        await fixture.repository.configure(waitsForTarget: true)
        fixture.connect(false)
        fixture.controller.setTarget(percent: 90)
        fixture.connect(true)
        #expect(await waitUntil { await fixture.repository.writes == ["target:90"] })
        fixture.controller.setTarget(percent: 95)
        await fixture.repository.configure()
        #expect(await fixture.repository.targetEvents.waitForSubscriber())
        await fixture.repository.targetEvents.send(true)
        #expect(await waitUntil { !fixture.controller.state.preferences.hasPendingChanges })
        #expect(await fixture.repository.writes == ["target:90", "target:95"])
        #expect(fixture.controller.state.preferences.confirmed?.maximumStateOfChargeDeciPercent == 950)
        await fixture.controller.stopAndWait()
    }

    @Test func restartRetainsIntentAndPendingCanBeCancelledDuringWrite() async {
        let fixture = ChargingPreferencesFixture.make()
        fixture.connect(false)
        fixture.controller.setTarget(percent: 90)
        await fixture.controller.stopAndWait()
        fixture.connect(false)
        #expect(fixture.controller.state.preferences.pendingTarget?.percent == 90)
        await fixture.repository.configure(waitsForTarget: true)
        fixture.connect(true)
        #expect(await waitUntil { await fixture.repository.writes == ["target:90"] })
        #expect(await fixture.repository.targetEvents.waitForSubscriber())
        fixture.controller.cancelPending()
        await fixture.repository.targetEvents.send(true)
        #expect(await waitUntil { !fixture.controller.state.isApplying })
        #expect(!fixture.controller.state.preferences.hasPendingChanges)
        #expect(await fixture.repository.writes == ["target:90"])
        await fixture.controller.stopAndWait()
    }
}
