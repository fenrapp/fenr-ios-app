import BikeDomain

#if DEBUG
@MainActor
enum BikeOnboardingPreviewFactory {
    static func makeViewModel(state: BikeOnboardingViewState) -> BikeOnboardingViewModel {
        let repository = BikeOnboardingPreviewRepository()
        return BikeOnboardingViewModel(
            useCases: .init(
                start: .init(repository: repository),
                connect: .init(repository: repository),
                observeConnection: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                saveProfile: .init(repository: repository)
            )
        ).configuredForPreview(state)
    }
}

private actor BikeOnboardingPreviewRepository: BikeRepository, BikeDiscoveryRepository, BikeProfileRepository {
    func start() async {}
    func stop() async {}
    func connect(vin _: String) async throws {}
    func disconnect() async throws {}
    func retrySecurityHandshake() async throws {}
    func readTelemetrySnapshot() async throws {}
    func observeTelemetry() async -> AsyncStream<BikeTelemetry> { .init { $0.finish() } }
    func observeConnection() async -> AsyncStream<BikeConnection> { .init { $0.finish() } }
    func observeDebugEvents() async -> AsyncStream<BikeDebugEvent> { .init { $0.finish() } }
    func startBikeDiscovery() async {}
    func stopBikeDiscovery() async {}
    func observeDiscoveredBikes() async -> AsyncStream<[DiscoveredBike]> { .init { $0.finish() } }
    func loadProfile() async -> BikeProfile? { nil }
    func saveProfile(_: BikeProfile) async {}
    func clearProfile() async {}
}

private extension BikeOnboardingViewModel {
    func configuredForPreview(_ state: BikeOnboardingViewState) -> Self {
        setPreviewState(state)
        return self
    }
}
#endif
