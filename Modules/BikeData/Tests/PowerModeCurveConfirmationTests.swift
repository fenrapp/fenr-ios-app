@testable import BikeData
import BikeDomain
import Testing

struct PowerModeCurveConfirmationTests {
    @Test func readsAndNoOpsDoNotClaimAdvanced() async {
        let store = BikeRepositoryStateStore()
        let value = PowerModeCurveConfirmationFixtures.configuration()
        let context = await store.curveReadContext(mapIndex: 0)
        _ = await store.confirmCurves(value, context: context)
        #expect(await store.currentTelemetry().activePowerModeConfiguration == nil)
        _ = await store.confirmCurves(value, context: context, advancedEditBaseline: value)
        #expect(await store.currentTelemetry().powerModeConfigurations[0]?.curveConfirmation.hasAdvancedCurve == false)
    }

    @Test func confirmedEditIsScopedToItsMapAndSurvivesMatchingRead() async {
        let store = BikeRepositoryStateStore()
        let baseline = PowerModeCurveConfirmationFixtures.configuration()
        let edited = PowerModeCurveConfirmationFixtures.configuration(power: 450)
        let context = await store.curveReadContext(mapIndex: 0)
        _ = await store.confirmCurves(edited, context: context, advancedEditBaseline: baseline)
        let next = await store.curveReadContext(mapIndex: 0)
        _ = await store.confirmCurves(edited, context: next)
        let telemetry = await store.currentTelemetry()
        #expect(telemetry.powerModeConfigurations[0]?.curveConfirmation.hasAdvancedCurve == true)
        #expect(telemetry.powerModeConfigurations[1] == nil)
    }

    @Test func restoringOneAxisPreservesTheOtherAdvancedCurve() {
        let baseline = PowerModeCurveConfirmationFixtures.configuration()
        let edited = PowerModeCurveConfirmationFixtures.configuration(power: 450, regeneration: 300)
        let confirmation = BikePowerModeCurveConfirmation().confirming(edited, advancedEditBaseline: baseline)
        let basicPower = PowerModeCurveConfirmationFixtures.configuration(regeneration: 300)
        let afterPower = confirmation.confirming(basicPower)
        #expect(afterPower.hasAdvancedCurve)
        #expect(!afterPower.confirming(baseline).hasAdvancedCurve)
    }

    @Test func unknownChangesAndFailedOperationsClearConfirmation() async {
        let baseline = PowerModeCurveConfirmationFixtures.configuration()
        let edited = PowerModeCurveConfirmationFixtures.configuration(power: 450)
        let confirmation = BikePowerModeCurveConfirmation().confirming(edited, advancedEditBaseline: baseline)
        #expect(!confirmation.confirming(PowerModeCurveConfirmationFixtures.configuration(power: 400)).hasAdvancedCurve)
        let store = BikeRepositoryStateStore()
        let context = await store.curveReadContext(mapIndex: 0)
        _ = await store.confirmCurves(edited, context: context, advancedEditBaseline: baseline)
        let failedRead = await store.curveReadContext(mapIndex: 0)
        _ = await store.confirmCurves(nil, context: failedRead)
        #expect(await store.currentTelemetry().powerModeConfigurations[0]?.curveConfirmation.hasAdvancedCurve == false)
    }

    @Test func disconnectedSessionRejectsLateConfirmation() async {
        let store = BikeRepositoryStateStore()
        let context = await store.curveReadContext(mapIndex: 0)
        _ = await store.resetSession(connectionState: .disconnected(reason: nil))
        let result = await store.confirmCurves(
            PowerModeCurveConfirmationFixtures.configuration(power: 450), context: context,
            advancedEditBaseline: PowerModeCurveConfirmationFixtures.configuration()
        )
        #expect(result == nil)
        #expect(await store.currentTelemetry().powerModeConfigurations.isEmpty)
    }

    @Test func concurrentMatchingReadRetainsNewConfirmation() async {
        let store = BikeRepositoryStateStore()
        let write = await store.curveReadContext(mapIndex: 0)
        let read = await store.curveReadContext(mapIndex: 0)
        let edited = PowerModeCurveConfirmationFixtures.configuration(power: 450)
        _ = await store.confirmCurves(
            edited, context: write, advancedEditBaseline: PowerModeCurveConfirmationFixtures.configuration()
        )
        _ = await store.confirmCurves(edited, context: read)
        #expect(await store.currentTelemetry().powerModeConfigurations[0]?.curveConfirmation.hasAdvancedCurve == true)
    }

    @Test func lateFailureDoesNotEraseNewerConfirmation() async {
        let store = BikeRepositoryStateStore()
        let older = await store.curveReadContext(mapIndex: 0)
        let newer = await store.curveReadContext(mapIndex: 0)
        _ = await store.confirmCurves(
            PowerModeCurveConfirmationFixtures.configuration(power: 450), context: newer,
            advancedEditBaseline: PowerModeCurveConfirmationFixtures.configuration()
        )
        #expect(await store.confirmCurves(nil, context: older) == nil)
        #expect(await store.currentTelemetry().powerModeConfigurations[0]?.curveConfirmation.hasAdvancedCurve == true)
    }
}
