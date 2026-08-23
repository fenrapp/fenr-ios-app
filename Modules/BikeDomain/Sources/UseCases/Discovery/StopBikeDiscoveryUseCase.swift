public struct StopBikeDiscoveryUseCase: Sendable {
    private let repository: any BikeDiscoveryRepository

    public init(repository: any BikeDiscoveryRepository) { self.repository = repository }

    public func execute() async { await repository.stopBikeDiscovery() }
}
