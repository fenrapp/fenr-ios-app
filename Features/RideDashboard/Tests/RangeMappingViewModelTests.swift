@testable import RideDashboard
import Testing
import TestSupport

@MainActor
struct RangeMappingViewModelTests {
    @Test("Refreshing history replaces a cached estimate without restarting the card")
    func historyRefreshInvalidatesPresentation() async {
        let fixture = RangeMappingTestFixture()
        fixture.model.setIsVisible(true)
        defer { fixture.model.stop() }
        #expect(await waitUntil { fixture.model.summary?.text == "62 km" })

        await fixture.repository.replaceCompletedTrips(with: [])
        await fixture.session.send(RangeMappingFixtures.snapshot(trip: nil, historyRevision: 1))
        #expect(await waitUntil { await fixture.repository.completedReadCount() == 2 })
        await fixture.model.historyLoadTaskForTesting?.value

        #expect(fixture.model.summary == nil)
        #expect(fixture.model.viewState.typicalRangeText == "\u{2014}")
    }

    @Test("Hidden summary remains current and showing the card publishes its cached result")
    func hiddenSummaryAndVisibility() async {
        let fixture = RangeMappingTestFixture()
        fixture.model.start()
        defer { fixture.model.stop() }
        #expect(await waitUntil { fixture.model.summary?.text == "62 km" })
        #expect(fixture.model.viewState == DashboardRangeViewData())
        await fixture.session.send(RangeMappingFixtures.snapshot(trip: nil, charge: 40))
        #expect(await waitUntil { fixture.model.summary?.text == "41 km" })
        #expect(fixture.model.viewState == DashboardRangeViewData())
        fixture.model.setIsVisible(true)
        #expect(fixture.model.viewState.summary == fixture.model.summary)
        #expect(fixture.model.viewState.batteryText == "40%")
    }

    @Test("Stop and pause restart correctly with identical snapshots")
    func restartIdenticalInput() async {
        let fixture = RangeMappingTestFixture()
        fixture.model.setIsVisible(true)
        defer { fixture.model.stop() }
        #expect(await waitUntil { fixture.model.summary?.text == "62 km" })
        let original = fixture.model.viewState
        fixture.model.pause()
        fixture.model.setIsVisible(true)
        #expect(fixture.model.viewState == original)
        fixture.model.stop()
        #expect(fixture.model.summary == nil)
        fixture.model.setIsVisible(true)
        #expect(await waitUntil { fixture.model.summary == original.summary })
        #expect(fixture.model.viewState == original)
        #expect(await fixture.repository.loadCount() == 2)
    }

    @Test("A changed history result with the same revision invalidates after stop and reload")
    func historyReplacementAndVIN() async {
        let fixture = RangeMappingTestFixture()
        fixture.model.setIsVisible(true)
        defer { fixture.model.stop() }
        #expect(await waitUntil { fixture.model.summary?.text == "62 km" })
        fixture.model.stop()
        await fixture.repository.replaceCompletedTrips(with: [])
        fixture.model.setIsVisible(true)
        #expect(await waitUntil { await fixture.repository.completedReadCount() == 2 })
        await fixture.model.historyLoadTaskForTesting?.value
        #expect(fixture.model.summary == nil)
        #expect(fixture.model.viewState.typicalRangeText == "\u{2014}")
        await fixture.repository.replaceCompletedTrips(with: [DashboardHistoryCardData.trip()])
        await fixture.session.send(RangeMappingFixtures.snapshot(trip: nil, vin: "FENRTEST000000002"))
        #expect(await waitUntil { await fixture.repository.completedReadCount() == 3 })
        await fixture.model.historyLoadTaskForTesting?.value
        #expect(fixture.model.summary == nil)
        await fixture.session.send(RangeMappingFixtures.snapshot(trip: nil))
        #expect(await waitUntil { fixture.model.summary?.text == "62 km" })
        #expect(await fixture.repository.loadCount() == 4)
    }
}
