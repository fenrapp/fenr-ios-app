import Foundation
import Observation
@testable import RideHistory
import Testing
import TestSupport

@MainActor
struct RideHistoryObservationTests {
    @Test("The separately observed ride detail updates on load and later unit changes")
    func observesDetailLoadAndUnitChanges() async throws {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        defer { fixture.viewModel.stop() }
        fixture.viewModel.start()
        try #require(await waitUntil { fixture.viewModel.viewState.status == .loaded })
        fixture.viewModel.loadDetail(id: trip.id)
        let loaded = ObservationChangeRecorder()
        withObservationTracking {
            _ = fixture.viewModel.detailViewState
        } onChange: {
            loaded.record()
        }
        try #require(await waitUntil { fixture.viewModel.detailViewState.status == .loaded })
        #expect(loaded.count == 1)
        #expect(fixture.viewModel.detailViewState.rideID == trip.id)
        let metricDistance = fixture.viewModel.detailViewState.distanceText
        let units = ObservationChangeRecorder()
        withObservationTracking {
            _ = fixture.viewModel.detailViewState.distanceText
        } onChange: {
            units.record()
        }
        await fixture.session.send(RideHistoryTestFactory.snapshot(measurementSystem: .imperial))
        try #require(await waitUntil { fixture.viewModel.detailViewState.distanceUnit == "mi" })
        #expect(fixture.viewModel.detailViewState.distanceText != metricDistance)
        #expect(units.count == 1)
        #expect(await fixture.operation.requestCount(for: .detail(trip.id)) == 1)
        await fixture.viewModel.stopAndWait()
    }
}
