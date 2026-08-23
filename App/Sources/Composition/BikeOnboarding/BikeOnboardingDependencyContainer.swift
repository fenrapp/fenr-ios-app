import BikeDomain
import BikeOnboarding

@MainActor
struct BikeOnboardingDependencyContainer {
    func makeViewModel(
        repository: any BikeRepository & BikeDiscoveryRepository,
        profileRepository: any BikeProfileRepository,
        initialVIN: String?,
        onCompleted: @escaping @MainActor (String) -> Void
    ) -> BikeOnboardingViewModel {
        BikeOnboardingViewModel(
            useCases: .init(
                connect: ConnectToBikeUseCase(repository: repository),
                observeConnection: ObserveBikeConnectionUseCase(repository: repository),
                startDiscovery: StartBikeDiscoveryUseCase(repository: repository),
                stopDiscovery: StopBikeDiscoveryUseCase(repository: repository),
                observeDiscoveredBikes: ObserveDiscoveredBikesUseCase(repository: repository),
                saveProfile: SaveBikeProfileUseCase(repository: profileRepository)
            ),
            initialVIN: initialVIN,
            onCompleted: onCompleted
        )
    }
}
