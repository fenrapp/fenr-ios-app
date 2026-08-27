import RideSessionDomain

public struct EfficiencyCardUseCases: Sendable {
    let loadTrend: LoadRideTripEfficiencyTrendUseCase

    public init(loadTrend: LoadRideTripEfficiencyTrendUseCase) {
        self.loadTrend = loadTrend
    }
}
