import Foundation

public struct CompleteRideTripUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(_ trip: RideTrip, at date: Date) async {
        await repository.completeTrip(trip, at: date)
    }
}
