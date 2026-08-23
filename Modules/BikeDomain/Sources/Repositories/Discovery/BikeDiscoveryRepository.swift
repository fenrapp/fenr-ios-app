public protocol BikeDiscoveryRepository: Sendable {
    func startBikeDiscovery() async
    func stopBikeDiscovery() async
    func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]>
}
