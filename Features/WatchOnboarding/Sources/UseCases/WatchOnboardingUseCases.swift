import BikeDomain

public struct WatchOnboardingUseCases: Sendable {
    let connectToBike: ConnectToBikeUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeDiscoveredBikes: ObserveDiscoveredBikesUseCase
    let startDiscovery: StartBikeDiscoveryUseCase
    let stopDiscovery: StopBikeDiscoveryUseCase
    let saveProfile: SaveBikeProfileUseCase

    public init(
        connectToBike: ConnectToBikeUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeDiscoveredBikes: ObserveDiscoveredBikesUseCase,
        startDiscovery: StartBikeDiscoveryUseCase,
        stopDiscovery: StopBikeDiscoveryUseCase,
        saveProfile: SaveBikeProfileUseCase
    ) {
        self.connectToBike = connectToBike
        self.observeConnection = observeConnection
        self.observeDiscoveredBikes = observeDiscoveredBikes
        self.startDiscovery = startDiscovery
        self.stopDiscovery = stopDiscovery
        self.saveProfile = saveProfile
    }
}
