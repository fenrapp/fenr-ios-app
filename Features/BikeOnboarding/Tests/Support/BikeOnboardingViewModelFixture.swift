import BikeDomain
@testable import BikeOnboarding

@MainActor
struct BikeOnboardingViewModelFixture {
    let repository: OnboardingRepository
    let profileRepository: OnboardingProfileRepository
    let clipboard: OnboardingClipboard
    let pinDeriver: OnboardingPinDeriver
    let timing: ControllableBikeOnboardingTiming
    let authorization: OnboardingBluetoothAuthorizationProvider
    let completion: OnboardingCompletionRecorder
    let viewModel: BikeOnboardingViewModel

    init(
        authorization initialAuthorization: BikeOnboardingBluetoothAuthorization = .allowed,
        initialVIN: String? = nil
    ) {
        let repository = OnboardingRepository()
        let profileRepository = OnboardingProfileRepository()
        let clipboard = OnboardingClipboard()
        let pinDeriver = OnboardingPinDeriver()
        let timing = ControllableBikeOnboardingTiming()
        let authorization = OnboardingBluetoothAuthorizationProvider(initialAuthorization)
        let completion = OnboardingCompletionRecorder()
        self.repository = repository
        self.profileRepository = profileRepository
        self.clipboard = clipboard
        self.pinDeriver = pinDeriver
        self.timing = timing
        self.authorization = authorization
        self.completion = completion
        let mapper = BikeOnboardingPresentationMapper()
        let repositoryStarter = BikeOnboardingRepositoryStarter(
            startRepository: .init(repository: repository)
        )
        let discoveryCoordinator = BikeOnboardingDiscoveryCoordinator(
            repositoryStarter: repositoryStarter,
            startDiscovery: .init(repository: repository),
            stopDiscovery: .init(repository: repository),
            observeDiscoveredBikes: .init(repository: repository),
            mapper: mapper,
            timing: timing.makeTiming()
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
            timing: timing.makeTiming(),
            authorizationProvider: { authorization.authorization }
        )
        let completionCoordinator = BikeOnboardingCompletionCoordinator(
            saveProfile: .init(repository: profileRepository), timing: timing.makeTiming()
        )
        let pairingCoordinator = BikeOnboardingPairingCoordinator(
            derivePin: .init(pinDeriver: pinDeriver), clipboard: clipboard
        )
        viewModel = BikeOnboardingViewModel(
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
            onCompleted: completion.record
        )
    }
}
