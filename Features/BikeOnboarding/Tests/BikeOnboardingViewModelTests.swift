import BikeDomain
import BikeOnboarding
import Testing
import TestSupport

@MainActor
@Suite("Bike onboarding view model")
struct BikeOnboardingViewModelTests {
    @Test("Normalizes an injected onboarding VIN")
    func normalizesInitialVIN() {
        let viewModel = BikeOnboardingViewModel(
            useCases: .init(
                connect: .init(repository: OnboardingRepository()),
                observeConnection: .init(repository: OnboardingRepository()),
                startDiscovery: .init(repository: OnboardingRepository()),
                stopDiscovery: .init(repository: OnboardingRepository()),
                observeDiscoveredBikes: .init(repository: OnboardingRepository()),
                saveProfile: .init(repository: OnboardingProfileRepository())
            ),
            initialVIN: "fenrtest000000001"
        )

        #expect(viewModel.viewState.vin == "FENRTEST000000001")
    }

    @Test("Does not save a profile before telemetry is received")
    func doesNotSaveBeforeTelemetry() async {
        let repository = OnboardingRepository()
        let profileRepository = OnboardingProfileRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: profileRepository)

        viewModel.vinChanged("FENRTEST000000001")
        advanceToConnection(viewModel)
        #expect(await waitUntil { await repository.connectedVIN() != nil })

        #expect(await profileRepository.loadProfile() == nil)
    }

    @Test("Saves the profile only after receiving telemetry")
    func savesAfterReceivingTelemetry() async {
        let repository = OnboardingRepository()
        let profileRepository = OnboardingProfileRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: profileRepository)
        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.vinChanged("FENRTEST000000001")
        advanceToConnection(viewModel)

        await repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")))
        #expect(await waitUntil { await profileRepository.loadProfile() != nil })

        #expect(await profileRepository.loadProfile() == .init(vin: "FENRTEST000000001"))
        viewModel.stopObserving()
    }

    @Test("Completes setup after saving a matching telemetry connection")
    func completesAfterMatchingTelemetry() async {
        let repository = OnboardingRepository()
        let profileRepository = OnboardingProfileRepository()
        let completionRecorder = OnboardingCompletionRecorder()
        let viewModel = BikeOnboardingViewModel(
            useCases: .init(
                connect: .init(repository: repository),
                observeConnection: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                saveProfile: .init(repository: profileRepository)
            ),
            onCompleted: { vin in
                Task { await completionRecorder.record(vin) }
            }
        )
        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.vinChanged("FENRTEST000000001")
        advanceToConnection(viewModel)

        await repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")))
        #expect(await waitUntil { await completionRecorder.value() != nil })

        #expect(await completionRecorder.value() == "FENRTEST000000001")
        viewModel.stopObserving()
    }

    private func makeViewModel(
        repository: OnboardingRepository,
        profileRepository: OnboardingProfileRepository
    ) -> BikeOnboardingViewModel {
        BikeOnboardingViewModel(
            useCases: .init(
                connect: .init(repository: repository),
                observeConnection: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                saveProfile: .init(repository: profileRepository)
            )
        )
    }

    private func advanceToConnection(_ viewModel: BikeOnboardingViewModel) {
        viewModel.next()
        viewModel.next()
        viewModel.next()
    }

    @Test("Selects a single discovered bike automatically")
    func selectsSingleDiscoveredBike() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startDiscovery()
        #expect(await waitUntil { await repository.isObservingDiscovery() })
        await repository.sendDiscoveredBikes([.init(vin: "FENRTEST000000001", rssi: -45)])
        #expect(await waitUntil { viewModel.viewState.vin == "FENRTEST000000001" })

        #expect(viewModel.viewState.discoveredBikes.count == 1)
        #expect(!viewModel.viewState.isDiscoveringBikes)
    }

    @Test("Starts discovery when entering identification")
    func startsDiscoveryWhenEnteringIdentification() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.next()
        viewModel.next()
        #expect(await waitUntil { await repository.isObservingDiscovery() })

        #expect(viewModel.viewState.step == .identify)
        #expect(viewModel.viewState.isDiscoveringBikes)
    }

    @Test("Keeps multiple discovered bikes available for selection")
    func keepsMultipleDiscoveredBikes() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())
        let first = DiscoveredBike(vin: "FENRTEST000000001", rssi: -55)
        let second = DiscoveredBike(vin: "FENRTEST000000001", rssi: -45)

        viewModel.startDiscovery()
        await waitUntil { await repository.isObservingDiscovery() }
        await repository.sendDiscoveredBikes([first, second])
        #expect(await waitUntil { viewModel.viewState.discoveredBikes.count == 2 })
        viewModel.selectDiscoveredBike(second)

        #expect(viewModel.viewState.vin == second.vin)
        #expect(!viewModel.viewState.isDiscoveringBikes)
    }

}
