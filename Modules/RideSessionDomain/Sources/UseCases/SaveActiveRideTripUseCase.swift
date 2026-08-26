public struct SaveActiveRideTripUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(_ trip: RideTrip) async {
        await repository.saveActiveTrip(trip)
    }
}
