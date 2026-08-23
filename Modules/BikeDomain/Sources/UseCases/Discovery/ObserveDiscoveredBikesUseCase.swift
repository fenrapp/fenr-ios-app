public struct ObserveDiscoveredBikesUseCase: Sendable {
    private let repository: any BikeDiscoveryRepository

    public init(repository: any BikeDiscoveryRepository) { self.repository = repository }

    public func execute() async -> AsyncStream<[DiscoveredBike]> {
        await repository.observeDiscoveredBikes()
    }
}
