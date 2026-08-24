import BikeDomain

public struct BikeOnboardingUseCases: Sendable {
    let start: StartBikeRepositoryUseCase
    let connect: ConnectToBikeUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let startDiscovery: StartBikeDiscoveryUseCase
    let stopDiscovery: StopBikeDiscoveryUseCase
    let observeDiscoveredBikes: ObserveDiscoveredBikesUseCase
    let saveProfile: SaveBikeProfileUseCase

    public init(
        start: StartBikeRepositoryUseCase,
        connect: ConnectToBikeUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        startDiscovery: StartBikeDiscoveryUseCase,
        stopDiscovery: StopBikeDiscoveryUseCase,
        observeDiscoveredBikes: ObserveDiscoveredBikesUseCase,
        saveProfile: SaveBikeProfileUseCase
    ) {
        self.start = start
        self.connect = connect
        self.observeConnection = observeConnection
        self.startDiscovery = startDiscovery
        self.stopDiscovery = stopDiscovery
        self.observeDiscoveredBikes = observeDiscoveredBikes
        self.saveProfile = saveProfile
    }
}
