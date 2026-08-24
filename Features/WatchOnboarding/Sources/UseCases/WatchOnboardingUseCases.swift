import BikeDomain

public struct WatchOnboardingUseCases: Sendable {
    let connectToBike: ConnectToBikeUseCase
    let observeConnection: ObserveBikeConnectionUseCase
    let observeDebugEvents: ObserveBikeDebugEventsUseCase
    let observeDiscoveredBikes: ObserveDiscoveredBikesUseCase
    let startDiscovery: StartBikeDiscoveryUseCase
    let stopDiscovery: StopBikeDiscoveryUseCase
    let saveProfile: SaveBikeProfileUseCase

    public init(
        connectToBike: ConnectToBikeUseCase,
        observeConnection: ObserveBikeConnectionUseCase,
        observeDebugEvents: ObserveBikeDebugEventsUseCase,
        observeDiscoveredBikes: ObserveDiscoveredBikesUseCase,
        startDiscovery: StartBikeDiscoveryUseCase,
        stopDiscovery: StopBikeDiscoveryUseCase,
        saveProfile: SaveBikeProfileUseCase
    ) {
        self.connectToBike = connectToBike
        self.observeConnection = observeConnection
        self.observeDebugEvents = observeDebugEvents
        self.observeDiscoveredBikes = observeDiscoveredBikes
        self.startDiscovery = startDiscovery
        self.stopDiscovery = stopDiscovery
        self.saveProfile = saveProfile
    }
}
