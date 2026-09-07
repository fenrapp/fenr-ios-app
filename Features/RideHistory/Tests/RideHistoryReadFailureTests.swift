import Foundation
@testable import RideHistory
import Testing
import TestSupport

@MainActor
struct RideHistoryReadFailureTests {
    @Test("An unreadable history is distinct from an empty history and can be retried")
    func initialFailureCanRetry() async {
        let fixture = RideHistoryTestFactory.make(trips: [])
        await fixture.repository.failNextHistory()
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .failed })
        #expect(fixture.viewModel.viewState.loadErrorMessage != nil)
        #expect(fixture.viewModel.viewState.errorMessage == nil)
        fixture.viewModel.refresh()
        #expect(await waitUntil { fixture.viewModel.viewState.status == .empty })
        #expect(fixture.viewModel.viewState.loadErrorMessage == nil)
        fixture.viewModel.stop()
    }

    @Test("Failed refresh keeps the current bike history and waits for retry")
    func failedRefreshKeepsHistory() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        await fixture.repository.failNextHistory()
        fixture.viewModel.refresh()
        #expect(await waitUntil { fixture.viewModel.viewState.loadErrorMessage != nil })
        #expect(fixture.viewModel.viewState.rides.first?.id == trip.id)
        await fixture.session.send(RideHistoryTestFactory.snapshot(measurementSystem: .imperial))
        #expect(await waitUntil { fixture.viewModel.viewState.rides.first?.distanceText.contains("mi") == true })
        #expect(await fixture.operation.requestCount(for: .history) == 2)
        fixture.viewModel.refresh()
        #expect(await waitUntil { fixture.viewModel.viewState.loadErrorMessage == nil })
        fixture.viewModel.stop()
    }

    @Test("Detail read failure differs from a missing ride and preserves cached detail")
    func detailFailuresPreserveCachedRide() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        await fixture.repository.failNextDetail()
        fixture.viewModel.loadDetail(id: trip.id)
        #expect(await waitUntil { fixture.viewModel.detailViewState.status == .failed })
        fixture.viewModel.loadDetail(id: trip.id)
        #expect(await waitUntil { fixture.viewModel.detailViewState.status == .loaded })
        let distance = fixture.viewModel.detailViewState.distanceText
        await fixture.repository.failNextDetail()
        fixture.viewModel.loadDetail(id: trip.id)
        #expect(await waitUntil { fixture.viewModel.detailViewState.loadErrorMessage != nil })
        #expect(fixture.viewModel.detailViewState.status == .loaded)
        #expect(fixture.viewModel.detailViewState.distanceText == distance)
        await fixture.repository.replaceTrips([])
        fixture.viewModel.loadDetail(id: trip.id)
        #expect(await waitUntil { fixture.viewModel.detailViewState.status == .unavailable })
        #expect(fixture.viewModel.detailViewState.loadErrorMessage == nil)
        fixture.viewModel.stop()
    }

    @Test("A late failure cannot replace a new bike, and pending first loads remain loading")
    func lateFailureCannotReplaceNewBike() async {
        let fixture = RideHistoryTestFactory.make(trips: [])
        await fixture.repository.failNextHistory()
        await fixture.operation.blockNext(.history)
        fixture.viewModel.start()
        await fixture.operation.waitForRequest(.history)
        await fixture.session.send(RideHistoryTestFactory.snapshot(measurementSystem: .imperial))
        #expect(fixture.viewModel.viewState.status == .loading)
        await fixture.session.send(RideHistoryTestFactory.snapshot(vin: "FENRTEST000000002"))
        #expect(await waitUntil { fixture.viewModel.viewState.status == .empty })
        await fixture.operation.releaseNext(.history)
        await fixture.operation.waitForCompletion(.history, count: 2)
        #expect(fixture.viewModel.viewState.status == .empty)
        #expect(fixture.viewModel.viewState.loadErrorMessage == nil)
        fixture.viewModel.stop()
    }
}
