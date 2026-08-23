import BikeDomain

public struct BikeOnboardingUseCases: Sendable {
    let connect: ConnectToBikeUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let startDiscovery: StartBikeDiscoveryUseCase
    let stopDiscovery: StopBikeDiscoveryUseCase
    let observeDiscoveredBikes: ObserveDiscoveredBikesUseCase
    let saveProfile: SaveBikeProfileUseCase

    public init(
        connect: ConnectToBikeUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        startDiscovery: StartBikeDiscoveryUseCase,
        stopDiscovery: StopBikeDiscoveryUseCase,
        observeDiscoveredBikes: ObserveDiscoveredBikesUseCase,
        saveProfile: SaveBikeProfileUseCase
    ) {
        self.connect = connect
        self.observeConnection = observeConnection
        self.startDiscovery = startDiscovery
        self.stopDiscovery = stopDiscovery
        self.observeDiscoveredBikes = observeDiscoveredBikes
        self.saveProfile = saveProfile
    }
}
