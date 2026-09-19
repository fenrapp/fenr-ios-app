import Foundation
@testable import RideNavigation
import RideSessionDomain
import Testing
import TestSupport

@MainActor
struct RideNavigationRangeTests {
    @Test func formatsRangeUsingConfiguredDistanceUnits() {
        let mapper = RideNavigationRangeMapper(estimator: RideRangeEstimator(), locale: Locale(identifier: "en_GB"))
        let history = [NavigationRangeFixtures.history()]
        #expect(mapper.map(snapshot: NavigationRangeFixtures.snapshot(), history: history)
            == RideNavigationRangeState(value: "51", unit: "km"))
        #expect(mapper.map(snapshot: NavigationRangeFixtures.snapshot(units: .imperial), history: history)
            == RideNavigationRangeState(value: "32", unit: "mi"))
    }

    @Test func unavailableTelemetryAndMissingConsumptionNeverInventRange() {
        let mapper = RideNavigationRangeMapper(estimator: RideRangeEstimator(), locale: Locale(identifier: "en_GB"))
        #expect(mapper.map(snapshot: NavigationRangeFixtures.snapshot(), history: []).value == "--")
        #expect(mapper.map(snapshot: NavigationRangeFixtures.snapshot(charge: nil),
                           history: [NavigationRangeFixtures.history()]).value == "--")
        #expect(mapper.map(snapshot: NavigationRangeFixtures.snapshot(isCanonical: false),
                           history: [NavigationRangeFixtures.history()]).value == "--")
    }

    @Test func updatesChargeAndUnitsAndRestartsWithoutControllingSharedSession() async {
        let fixture = NavigationRangeTestFixture()
        fixture.model.start()
        fixture.model.start()
        #expect(await waitUntil { fixture.model.state.value == "51" })
        #expect(await fixture.session.observationCount == 1)
        await fixture.session.send(NavigationRangeFixtures.snapshot(units: .imperial, charge: 25))
        #expect(await waitUntil { fixture.model.state == RideNavigationRangeState(value: "16", unit: "mi") })
        await fixture.session.send(NavigationRangeFixtures.snapshot(isCanonical: false))
        #expect(await waitUntil { fixture.model.state.value == "--" })
        fixture.model.stop()
        #expect(fixture.model.state == RideNavigationRangeState())
        await fixture.session.send(NavigationRangeFixtures.snapshot(charge: 25))
        fixture.model.start()
        #expect(await waitUntil { fixture.model.state.value == "26" })
        #expect(await fixture.session.lifecycleCalls == 0)
        fixture.model.stop()
    }

    @Test func discardsHistoryFromPreviousBike() async {
        let fixture = NavigationRangeTestFixture()
        await fixture.repository.blockNextRead()
        fixture.model.start()
        #expect(await waitUntil { await fixture.repository.isBlocked })
        let pendingLoad = fixture.model.historyLoadTaskForTesting
        await fixture.session.send(NavigationRangeFixtures.snapshot(vin: "FENRTEST000000002"))
        #expect(await waitUntil { await fixture.repository.loadCount == 2 })
        await fixture.repository.releaseRead()
        await pendingLoad?.value
        #expect(fixture.model.state.value == "--")
        fixture.model.stop()
    }

    @Test func discardsPendingHistoryAfterStopAndReloadsOnRestart() async {
        let fixture = NavigationRangeTestFixture()
        await fixture.repository.blockNextRead()
        fixture.model.start()
        #expect(await waitUntil { await fixture.repository.isBlocked })
        let pendingLoad = fixture.model.historyLoadTaskForTesting
        fixture.model.stop()
        await fixture.repository.releaseRead()
        await pendingLoad?.value
        #expect(fixture.model.state == RideNavigationRangeState())
        fixture.model.start()
        #expect(await waitUntil { fixture.model.state.value == "51" })
        #expect(await fixture.repository.loadCount == 2)
        fixture.model.stop()
    }

    @Test func reloadsHistoryOnlyWhenItsRevisionChanges() async {
        let fixture = NavigationRangeTestFixture()
        fixture.model.start()
        defer { fixture.model.stop() }
        #expect(await waitUntil { fixture.model.state.value == "51" })
        await fixture.session.send(NavigationRangeFixtures.snapshot(charge: 25))
        #expect(await waitUntil { fixture.model.state.value == "26" })
        #expect(await fixture.repository.loadCount == 1)
        await fixture.session.send(NavigationRangeFixtures.snapshot(revision: 1))
        #expect(await waitUntil { await fixture.repository.loadCount == 2 })
        await fixture.model.historyLoadTaskForTesting?.value
        #expect(fixture.model.state.value == "51")
    }

}
