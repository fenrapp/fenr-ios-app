import RideSessionDomain

public struct RideHistoryUseCases: Sendable {
    let loadHistory: LoadRideTripHistoryUseCase
    let loadDetail: LoadRideTripDetailUseCase

    public init(
        loadHistory: LoadRideTripHistoryUseCase,
        loadDetail: LoadRideTripDetailUseCase
    ) {
        self.loadHistory = loadHistory
        self.loadDetail = loadDetail
    }
}
