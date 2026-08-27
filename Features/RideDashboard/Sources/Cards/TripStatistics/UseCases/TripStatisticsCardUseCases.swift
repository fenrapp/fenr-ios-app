import RideSessionDomain

public struct TripStatisticsCardUseCases: Sendable {
    let loadStatistics: LoadRideTripStatisticsUseCase

    public init(loadStatistics: LoadRideTripStatisticsUseCase) {
        self.loadStatistics = loadStatistics
    }
}
