import Foundation
import RideDashboard
import RideSession
import RideSessionDomain

@MainActor
struct CurrentTripCardDependencyContainer {
    func makeViewModels(
        dependencies: CurrentTripCardDependencies
    ) -> CurrentTripCardViewModels {
        let rideTripRepository = dependencies.rideTripRepository
        return CurrentTripCardViewModels(
            currentTrip: CurrentTripCardViewModel(
                session: dependencies.rideSession,
                mapper: RideDashboardMapperFactory.makeCurrentTripMapper(locale: .autoupdatingCurrent)
            ),
            statistics: TripStatisticsCardViewModel(
                useCases: .init(
                    loadStatistics: .init(
                        repository: rideTripRepository,
                        aggregator: RideTripStatisticsAggregator()
                    )
                ),
                mapper: RideDashboardMapperFactory.makeTripStatisticsMapper(locale: .autoupdatingCurrent),
                session: dependencies.rideSession
            ),
            efficiency: EfficiencyCardViewModel(
                useCases: .init(
                    loadTrend: .init(repository: rideTripRepository)
                ),
                mapper: RideDashboardMapperFactory.makeEfficiencyMapper(locale: .autoupdatingCurrent),
                session: dependencies.rideSession
            )
        )
    }
}

struct CurrentTripCardDependencies {
    let rideTripRepository: any RideTripRepository
    let rideSession: any RideSessionService
}

@MainActor
struct CurrentTripCardViewModels {
    let currentTrip: CurrentTripCardViewModel
    let statistics: TripStatisticsCardViewModel
    let efficiency: EfficiencyCardViewModel
}
