import BikeDomain

#if DEBUG
@MainActor
enum BikeOnboardingPreviewFactory {
    static func makeViewModel(state: BikeOnboardingViewState) -> BikeOnboardingViewModel {
        let repository = BikeOnboardingPreviewRepository()
        let mapper = BikeOnboardingPresentationMapper()
        let timing = BikeOnboardingTiming.live
        let repositoryStarter = BikeOnboardingRepositoryStarter(
            startRepository: .init(repository: repository)
        )
        let discoveryCoordinator = BikeOnboardingDiscoveryCoordinator(
            repositoryStarter: repositoryStarter,
            startDiscovery: .init(repository: repository),
            stopDiscovery: .init(repository: repository),
            observeDiscoveredBikes: .init(repository: repository),
            mapper: mapper,
            timing: timing
        )
        let connectionCoordinator = BikeOnboardingConnectionCoordinator(
            repositoryStarter: repositoryStarter,
            connectToBike: .init(repository: repository),
            disconnectBike: .init(repository: repository),
            observeConnection: .init(repository: repository),
            mapper: mapper
        )
        let bluetoothAccessCoordinator = BikeOnboardingBluetoothAccessCoordinator(
            repositoryStarter: repositoryStarter,
            timing: timing,
            authorizationProvider: { .allowed }
        )
        let completionCoordinator = BikeOnboardingCompletionCoordinator(
            saveProfile: .init(repository: repository),
            timing: timing
        )
        let pairingCoordinator = BikeOnboardingPairingCoordinator(
            derivePin: .init(pinDeriver: BikeOnboardingPreviewPinDeriver()),
            clipboard: BikeOnboardingPreviewClipboard()
        )
        return BikeOnboardingViewModel(
            discoveryCoordinator: discoveryCoordinator,
            connectionCoordinator: connectionCoordinator,
            bluetoothAccessCoordinator: bluetoothAccessCoordinator,
            completionCoordinator: completionCoordinator,
            pairingCoordinator: pairingCoordinator,
            eventCoordinator: BikeOnboardingEventCoordinator(
                discoveryCoordinator: discoveryCoordinator,
                connectionCoordinator: connectionCoordinator,
                bluetoothAccessCoordinator: bluetoothAccessCoordinator,
                completionCoordinator: completionCoordinator
            ),
            eventReducer: BikeOnboardingEventReducer(pairingCoordinator: pairingCoordinator),
            initialVIN: nil
        ).configuredForPreview(state)
    }
}

@MainActor
private struct BikeOnboardingPreviewClipboard: BikeOnboardingClipboardWriting {
    func copy(_: String) {}
}

private struct BikeOnboardingPreviewPinDeriver: BikePinDeriving {
    func derivePin(vin _: String) -> String { "123456" }
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
