import Foundation
@testable import RideHistory
import Testing
import TestSupport

@MainActor
@Suite("Ride history view model")
struct RideHistoryViewModelTests {
    @Test("Loads the current bike history and responds to unit and revision changes")
    func loadsAndRefreshesHistory() async {
        let first = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [first])
        fixture.viewModel.start()
        await fixture.session.waitForSubscriber()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        #expect(fixture.viewModel.viewState.rides[0].distanceText.contains("km"))

        let second = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 3_000))
        await fixture.repository.replaceTrips([first, second])
        await fixture.session.send(RideHistoryTestFactory.snapshot(
            measurementSystem: .imperial,
            revision: 1
        ))

        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 2 })
        #expect(fixture.viewModel.viewState.rides[0].distanceText.contains("mi"))
        fixture.viewModel.stop()
    }

    @Test("Loads detailed buckets only when a ride is opened")
    func loadsDetail() async {
        let date = Date(timeIntervalSince1970: 4_000)
        let trip = RideHistoryFixtures.trip(
            startedAt: date,
            buckets: RideHistoryFixtures.buckets(startedAt: date)
        )
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })

        fixture.viewModel.loadDetail(id: trip.id)

        #expect(await waitUntil { fixture.viewModel.detailViewState.status == .loaded })
        #expect(fixture.viewModel.detailViewState.batteryPoints.count == 4)
        #expect(fixture.viewModel.detailViewState.efficiencyPoints.count == 4)
        fixture.viewModel.stop()
    }

    @Test("Deletes a ride and reports a failed deletion")
    func deletesAndReportsFailure() async {
        let first = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let second = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 1_000))
        let fixture = RideHistoryTestFactory.make(trips: [first, second])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 2 })

        fixture.viewModel.deleteRide(id: first.id)
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        #expect(fixture.viewModel.viewState.rides.first?.id == second.id)

        await fixture.session.setDeleteSucceeds(false)
        fixture.viewModel.deleteRide(id: second.id)
        #expect(await waitUntil { fixture.viewModel.viewState.errorMessage != nil })
        #expect(fixture.viewModel.viewState.rides.count == 1)
        fixture.viewModel.dismissError()
        #expect(fixture.viewModel.viewState.errorMessage == nil)
        fixture.viewModel.stop()
    }

    @Test("Deletes multiple selected rides serially")
    func deletesMultipleRides() async {
        let first = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 3_000))
        let second = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let third = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 1_000))
        let fixture = RideHistoryTestFactory.make(trips: [first, second, third])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 3 })

        fixture.viewModel.deleteRides(ids: [first.id, third.id])

        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        #expect(fixture.viewModel.viewState.rides.first?.id == second.id)
        #expect(fixture.viewModel.viewState.isDeleting == false)
        fixture.viewModel.stop()
    }

    @Test("Shows unavailable until a confirmed bike identity exists")
    func requiresConfirmedBike() async {
        let fixture = RideHistoryTestFactory.make(trips: [])
        fixture.viewModel.start()
        await fixture.session.send(.init(vehicleIdentity: .temporary(UUID())))

        #expect(await waitUntil { fixture.viewModel.viewState.status == .bikeUnavailable })
        fixture.viewModel.stop()
    }

    @Test("Changing bikes clears detail and reloads only the new bike history")
    func changesBike() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        fixture.viewModel.loadDetail(id: trip.id)
        #expect(await waitUntil { fixture.viewModel.detailViewState.status == .loaded })

        await fixture.session.send(RideHistoryTestFactory.snapshot(
            vin: RideHistoryFixtures.secondVIN,
            revision: 1
        ))

        #expect(await waitUntil { fixture.viewModel.viewState.status == .empty })
        #expect(fixture.viewModel.detailViewState.status == .idle)
        fixture.viewModel.stop()
    }

    @Test("Refresh waits until an in-flight deletion finishes")
    func refreshDoesNotStartWhileDeletionIsInFlight() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        await fixture.operation.blockNext(.deletion(trip.id))

        fixture.viewModel.deleteRide(id: trip.id)
        await fixture.operation.waitForRequest(.deletion(trip.id))
        let historyRequestCount = await fixture.operation.requestCount(for: .history)

        fixture.viewModel.refresh()

        #expect(await fixture.operation.requestCount(for: .history) == historyRequestCount)
        await fixture.operation.releaseNext(.deletion(trip.id))
        #expect(await waitUntil { fixture.viewModel.viewState.status == .empty })
        fixture.viewModel.stop()
    }

    @Test("Stopping allows an in-flight deletion to finish")
    func stopAllowsInFlightDeletionToFinish() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        await fixture.operation.blockNext(.deletion(trip.id))

        fixture.viewModel.deleteRide(id: trip.id)
        await fixture.operation.waitForRequest(.deletion(trip.id))
        fixture.viewModel.stop()
        await fixture.operation.releaseNext(.deletion(trip.id))

        #expect(await waitUntil { fixture.viewModel.viewState.status == .empty })
        #expect(fixture.viewModel.viewState.isDeleting == false)
    }

    @Test("Stopping allows the presented detail load to finish")
    func stopAllowsPresentedDetailLoadToFinish() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        await fixture.operation.blockNext(.detail(trip.id))

        fixture.viewModel.loadDetail(id: trip.id)
        await fixture.operation.waitForRequest(.detail(trip.id))
        fixture.viewModel.stop()
        await fixture.operation.releaseNext(.detail(trip.id))

        #expect(await waitUntil { fixture.viewModel.detailViewState.status == .loaded })
        #expect(fixture.viewModel.detailViewState.rideID == trip.id)
    }

    @Test("Clearing detail rejects a stale load result")
    func clearDetailCancelsStaleDetailLoad() async {
        let trip = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let fixture = RideHistoryTestFactory.make(trips: [trip])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 1 })
        await fixture.operation.blockNext(.detail(trip.id))

        fixture.viewModel.loadDetail(id: trip.id)
        await fixture.operation.waitForRequest(.detail(trip.id))
        fixture.viewModel.clearDetail(id: trip.id)
        await fixture.operation.releaseNext(.detail(trip.id))
        await fixture.operation.waitForCompletion(.detail(trip.id))

        #expect(fixture.viewModel.detailViewState.status == .idle)
        #expect(fixture.viewModel.detailViewState.rideID == nil)
        fixture.viewModel.stop()
    }

    @Test("A revision change rejects a stale history load result")
    func revisionChangeCancelsStaleHistoryLoad() async {
        let first = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 1_000))
        let second = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let latest = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 3_000))
        let fixture = RideHistoryTestFactory.make(trips: [first])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.map(\.id) == [first.id] })
        await fixture.repository.replaceTrips([second])
        await fixture.operation.blockNext(.history)

        await fixture.session.send(RideHistoryTestFactory.snapshot(revision: 1))
        await fixture.operation.waitForRequest(.history, count: 2)
        await fixture.repository.replaceTrips([latest])
        await fixture.session.send(RideHistoryTestFactory.snapshot(revision: 2))
        await fixture.operation.waitForRequest(.history, count: 3)
        #expect(await waitUntil { fixture.viewModel.viewState.rides.map(\.id) == [latest.id] })

        await fixture.operation.releaseNext(.history)
        await fixture.operation.waitForCompletion(.history, count: 3)
        #expect(fixture.viewModel.viewState.rides.map(\.id) == [latest.id])
        fixture.viewModel.stop()
    }

    @Test("Partial bulk deletion preserves failed rides and reports the error")
    func reportsPartialBulkDeletionAndPreservesFailedRides() async {
        let first = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 3_000))
        let failed = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 2_000))
        let third = RideHistoryFixtures.trip(startedAt: Date(timeIntervalSince1970: 1_000))
        let fixture = RideHistoryTestFactory.make(trips: [first, failed, third])
        fixture.viewModel.start()
        #expect(await waitUntil { fixture.viewModel.viewState.rides.count == 3 })
        await fixture.session.setDeletionResults([
            first.id: true,
            failed.id: false,
            third.id: true
        ])

        fixture.viewModel.deleteRides(ids: [third.id, first.id, failed.id])

        #expect(await waitUntil {
            fixture.viewModel.viewState.rides.map(\.id) == [failed.id]
                && fixture.viewModel.viewState.isDeleting == false
        })
        #expect(fixture.viewModel.viewState.errorMessage == "Some rides could not be deleted. Please try again.")
        let deletionOrder = await fixture.operation.requests.compactMap { request -> UUID? in
            guard case .deletion(let id) = request else { return nil }
            return id
        }
        #expect(deletionOrder == [first.id, failed.id, third.id])
        fixture.viewModel.stop()
    }
}
