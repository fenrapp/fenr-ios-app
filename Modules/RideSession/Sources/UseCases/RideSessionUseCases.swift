import RideSessionDomain

public struct RideSessionUseCases: Sendable {
    let prepare: PrepareRideTripSessionUseCase

    public init(prepare: PrepareRideTripSessionUseCase) {
        self.prepare = prepare
    }
}
