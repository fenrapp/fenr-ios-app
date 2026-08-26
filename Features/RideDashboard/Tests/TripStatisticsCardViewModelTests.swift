import Foundation
import RideDashboard
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

    @Test("Defers invalidated history refresh until statistics are visible")
    func defersInvalidatedRefresh() async {
        let repository = CurrentTripCardTripRepository(
            completedTrips: [makeTrip(distance: 12, maximumSpeed: 80)]
        )
        let viewModel = makeViewModel(repository: repository)
        viewModel.setIsVisible(true)
        #expect(await waitUntil { await repository.loadCount() == 1 })

        viewModel.setIsVisible(false)
        await repository.replaceCompletedTrips([
            makeTrip(distance: 12, maximumSpeed: 80),
            makeTrip(distance: 8, maximumSpeed: 90)
        ])
        viewModel.invalidate()
        await Task.yield()

        #expect(await repository.loadCount() == 1)

        viewModel.setIsVisible(true)
        #expect(await waitUntil {
            await repository.loadCount() == 2 && viewModel.viewState.statusText == "2 SAVED TRIPS"
        })
        #expect(viewModel.viewState.totalDistance.valueText == "20")
        #expect(viewModel.viewState.maximumSpeed.valueText == "90")
    }

    private func makeViewModel(
        repository: CurrentTripCardTripRepository
    ) -> TripStatisticsCardViewModel {
        TripStatisticsCardViewModel(
            useCases: .init(
                loadStatistics: .init(
                    repository: repository,
                    aggregator: RideTripStatisticsAggregator()
                ),
                observeSettings: .init(
                    repository: CurrentTripCardSettingsRepository()
                )
            ),
            mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(
                locale: Locale(identifier: "en_GB")
            )
        )
    }

    private func makeTrip(distance: Double, maximumSpeed: Double) -> RideTrip {
        RideTrip(
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
