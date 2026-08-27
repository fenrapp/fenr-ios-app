import Foundation

public struct PrepareRideTripSessionUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(context: BikeSessionContext) async -> RideTrip? {
        await repository.prepare(context: context)
    }
}
