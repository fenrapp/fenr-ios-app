public struct StartBikeDiscoveryUseCase: Sendable {
    private let repository: any BikeDiscoveryRepository

    public init(repository: any BikeDiscoveryRepository) { self.repository = repository }

    public func execute() async { await repository.startBikeDiscovery() }
}
