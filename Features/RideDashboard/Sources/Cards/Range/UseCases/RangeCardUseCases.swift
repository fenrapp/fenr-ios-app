import RideSessionDomain

public struct RangeCardUseCases: Sendable {
    let loadHistory: LoadRideTripRangeHistoryUseCase

    public init(loadHistory: LoadRideTripRangeHistoryUseCase) {
        self.loadHistory = loadHistory
    }
}
