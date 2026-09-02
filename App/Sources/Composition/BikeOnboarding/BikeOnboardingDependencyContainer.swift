import BikeDomain
import BikeOnboarding

@MainActor
struct BikeOnboardingDependencyContainer {
    func makeViewModel(
        repository: any BikeRepository & BikeDiscoveryRepository,
        pinDeriver: any BikePinDeriving,
        profileRepository: any BikeProfileRepository,
        initialVIN: String?,
        onCompleted: @escaping @MainActor (String) -> Void
    ) -> BikeOnboardingViewModel {
        let bluetoothAuthorization = SystemBikeOnboardingBluetoothAuthorizationProvider()
        let mapper = BikeOnboardingPresentationMapper()
        let timing = BikeOnboardingTiming.live
        let repositoryStarter = BikeOnboardingRepositoryStarter(
            startRepository: StartBikeRepositoryUseCase(repository: repository)
        )
        let discoveryCoordinator = BikeOnboardingDiscoveryCoordinator(
            repositoryStarter: repositoryStarter,
            startDiscovery: StartBikeDiscoveryUseCase(repository: repository),
            stopDiscovery: StopBikeDiscoveryUseCase(repository: repository),
            observeDiscoveredBikes: ObserveDiscoveredBikesUseCase(repository: repository),
            mapper: mapper,
            timing: timing
        )
        let connectionCoordinator = BikeOnboardingConnectionCoordinator(
            repositoryStarter: repositoryStarter,
            connectToBike: ConnectToBikeUseCase(repository: repository),
            disconnectBike: DisconnectBikeUseCase(repository: repository),
            observeConnection: ObserveBikeConnectionUseCase(repository: repository),
            mapper: mapper
        )
        let bluetoothAccessCoordinator = BikeOnboardingBluetoothAccessCoordinator(
            repositoryStarter: repositoryStarter,
            timing: timing,
            authorizationProvider: { bluetoothAuthorization.authorization }
        )
        let completionCoordinator = BikeOnboardingCompletionCoordinator(
            saveProfile: SaveBikeProfileUseCase(repository: profileRepository),
            timing: timing
        )
        let pairingCoordinator = BikeOnboardingPairingCoordinator(
            derivePin: DeriveBikePinUseCase(pinDeriver: pinDeriver),
            clipboard: SystemBikeOnboardingClipboard()
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
            initialVIN: initialVIN,
            onCompleted: onCompleted
        )
    }
}
