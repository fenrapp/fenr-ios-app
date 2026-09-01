import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import Testing
import TestSupport

@MainActor
@Suite("Trip statistics card view model")
struct TripStatisticsCardViewModelTests {
    @Test("Loads lazily once and reuses the cached aggregate")
    func loadsLazilyAndCaches() async {
        let repository = CurrentTripCardTripRepository(
            completedTrips: [makeTrip(distance: 12, maximumSpeed: 80)]
        )
        let viewModel = makeViewModel(repository: repository)

        #expect(await repository.loadCount() == 0)

        viewModel.setIsVisible(true)
        #expect(await waitUntil {
            await repository.loadCount() == 1 && viewModel.viewState.statusText == "1 SAVED TRIP"
        })

        viewModel.setIsVisible(false)
        viewModel.setIsVisible(true)
        await Task.yield()

        #expect(await repository.loadCount() == 1)
        #expect(viewModel.viewState.totalDistance.valueText == "12")
    }

    @Test("Defers revised history while hidden and reloads when shown")
    func reloadsRevisedHistoryWhenVisible() async {
        let repository = CurrentTripCardTripRepository(
            completedTrips: [makeTrip(distance: 12, maximumSpeed: 80)]
        )
        let session = TestRideSessionService(snapshot: .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            isCanonicalTelemetryAvailable: true
        ))
        let viewModel = makeViewModel(repository: repository, session: session)
        viewModel.setIsVisible(true)
        #expect(await waitUntil { await repository.loadCount() == 1 })

        viewModel.setIsVisible(false)
        await repository.replaceCompletedTrips(with: [
            makeTrip(distance: 12, maximumSpeed: 80),
            makeTrip(distance: 8, maximumSpeed: 70)
        ])
        await session.send(.init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            historyRevision: 1,
            isCanonicalTelemetryAvailable: true
        ))
        await Task.yield()
        #expect(await repository.loadCount() == 1)

        viewModel.setIsVisible(true)
        #expect(await waitUntil {
            await repository.loadCount() == 2
                && viewModel.viewState.statusText == "2 SAVED TRIPS"
        })
    }

    private func makeViewModel(
        repository: CurrentTripCardTripRepository,
        session: TestRideSessionService? = nil
    ) -> TripStatisticsCardViewModel {
        let session = session ?? TestRideSessionService(snapshot: .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            isCanonicalTelemetryAvailable: true
        ))
        return TripStatisticsCardViewModel(
            useCases: .init(
                loadStatistics: .init(
                    repository: repository,
                    aggregator: RideTripStatisticsAggregator()
                )
            ),
            mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(
                locale: Locale(identifier: "en_GB")
            ),
            session: session
        )
    }

    private func makeTrip(distance: Double, maximumSpeed: Double) -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin("TESTVIN0000000001"),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            endedAt: .distantPast,
            distanceKilometers: distance,
            elapsedSeconds: 3_600,
            averageSpeedKilometersPerHour: 30,
            maximumSpeedKilometersPerHour: maximumSpeed
        )
    }
}
