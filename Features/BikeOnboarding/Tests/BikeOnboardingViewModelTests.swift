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
                start: .init(repository: OnboardingRepository()),
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

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.vinChanged("FENRTEST000000001")
        await advanceToConnection(viewModel, repository: repository)
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
        await advanceToConnection(viewModel, repository: repository)

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
                start: .init(repository: repository),
                connect: .init(repository: repository),
                observeConnection: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                saveProfile: .init(repository: profileRepository)
            ),
            bluetoothAuthorization: { .notDetermined },
            onCompleted: { vin in
                Task { await completionRecorder.record(vin) }
            }
        )
        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.vinChanged("FENRTEST000000001")
        await advanceToConnection(viewModel, repository: repository)

        await repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")))
        #expect(await waitUntil { await completionRecorder.value() != nil })

        #expect(await completionRecorder.value() == "FENRTEST000000001")
        viewModel.stopObserving()
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

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.next()
        viewModel.next()
        await repository.sendConnection(.init(state: .idle))
        #expect(await waitUntil { await repository.isObservingDiscovery() })

        #expect(viewModel.viewState.step == .identify)
        #expect(viewModel.viewState.isDiscoveringBikes)
    }

    @Test("Does not start Bluetooth before preparation continue")
    func doesNotStartBluetoothBeforePreparationContinue() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        viewModel.next()

        #expect(viewModel.viewState.step == .preparation)
        #expect(await repository.startCount() == 0)
    }

    @Test("Requests Bluetooth access from preparation before identifying")
    func requestsBluetoothAccessBeforeIdentifying() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        viewModel.next()
        viewModel.next()

        #expect(await waitUntil { await repository.startCount() == 1 })
        #expect(viewModel.viewState.step == .preparation)
        #expect(viewModel.viewState.isRequestingBluetoothAccess)

        await repository.sendConnection(.init(state: .idle))
        #expect(await waitUntil { viewModel.viewState.step == .identify })
        #expect(!viewModel.viewState.isRequestingBluetoothAccess)
    }

    @Test("Shows settings immediately when Bluetooth permission is already denied")
    func showsSettingsImmediatelyWhenBluetoothPermissionIsDenied() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(
            repository: repository,
            profileRepository: OnboardingProfileRepository(),
            bluetoothAuthorization: { .denied }
        )

        viewModel.startObserving()
        viewModel.next()

        #expect(viewModel.viewState.step == .preparation)
        #expect(!viewModel.viewState.isRequestingBluetoothAccess)
        #expect(viewModel.viewState.showsBluetoothSettingsButton)
        #expect(viewModel.viewState.errorMessage?.contains("Settings") == true)

        viewModel.next()

        #expect(await repository.startCount() == 0)
        #expect(!viewModel.viewState.isRequestingBluetoothAccess)
        #expect(viewModel.viewState.showsBluetoothSettingsButton)
    }

    @Test("Requires a valid VIN before connection")
    func requiresValidVINBeforeConnection() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.next()
        viewModel.next()
        await repository.sendConnection(.init(state: .idle))
        #expect(await waitUntil { viewModel.viewState.step == .identify })

        #expect(!viewModel.viewState.canContinue)
        viewModel.vinChanged("FENRTEST000000001")
        #expect(viewModel.viewState.canContinue)
    }

    @Test("Maps connection states to onboarding phases")
    func mapsConnectionStatesToOnboardingPhases() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.vinChanged("FENRTEST000000001")
        await advanceToConnection(viewModel, repository: repository)
        #expect(viewModel.viewState.connectionPhase == .scanning)

        await repository.sendConnection(.init(
            state: .connecting(vin: "FENRTEST000000001", peripheralName: "FENRTEST000000001")
        ))
        #expect(await waitUntil { viewModel.viewState.connectionPhase == .connecting })
        await repository.sendConnection(.init(state: .discovering(peripheralName: "FENRTEST000000001")))
        #expect(await waitUntil { viewModel.viewState.connectionPhase == .discovering })
        await repository.sendConnection(.init(state: .authenticating(peripheralName: "FENRTEST000000001")))
        #expect(await waitUntil { viewModel.viewState.connectionPhase == .authenticating })
        await repository.sendConnection(.init(state: .subscribed(peripheralName: "FENRTEST000000001")))
        #expect(await waitUntil { viewModel.viewState.connectionPhase == .subscribing })
    }

    @Test("Blocks onboarding when Bluetooth permission is denied")
    func blocksWhenBluetoothPermissionIsDenied() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.next()
        viewModel.next()
        await repository.sendConnection(.init(state: .bluetoothUnauthorized))

        #expect(await waitUntil { !viewModel.viewState.isRequestingBluetoothAccess })
        #expect(viewModel.viewState.step == .preparation)
        #expect(viewModel.viewState.errorMessage?.contains("Settings") == true)
        #expect(viewModel.viewState.showsBluetoothSettingsButton)
    }

    @Test("Does not show app settings for Bluetooth powered off")
    func doesNotShowSettingsWhenBluetoothIsPoweredOff() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.next()
        viewModel.next()
        await repository.sendConnection(.init(state: .bluetoothPoweredOff))

        #expect(await waitUntil { !viewModel.viewState.isRequestingBluetoothAccess })
        #expect(viewModel.viewState.step == .preparation)
        #expect(!viewModel.viewState.showsBluetoothSettingsButton)
    }

    @Test("Does not request Bluetooth again after permission is denied")
    func doesNotRequestBluetoothAgainAfterPermissionDenied() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())

        viewModel.startObserving()
        #expect(await waitUntil { await repository.isObservingConnection() })
        viewModel.next()
        viewModel.next()
        #expect(await waitUntil { await repository.startCount() == 1 })
        await repository.sendConnection(.init(state: .bluetoothUnauthorized))
        #expect(await waitUntil { viewModel.viewState.showsBluetoothSettingsButton })

        viewModel.next()

        #expect(await repository.startCount() == 1)
        #expect(viewModel.viewState.step == .preparation)
        #expect(viewModel.viewState.errorMessage?.contains("Settings") == true)
        #expect(viewModel.viewState.showsBluetoothSettingsButton)
    }

    @Test("Keeps multiple discovered bikes available for selection")
    func keepsMultipleDiscoveredBikes() async {
        let repository = OnboardingRepository()
        let viewModel = makeViewModel(repository: repository, profileRepository: OnboardingProfileRepository())
        let first = DiscoveredBike(vin: "FENRTEST000000001", rssi: -55)
        let second = DiscoveredBike(vin: "FENRTEST000000003", rssi: -45)

        viewModel.startDiscovery()
        #expect(await waitUntil { await repository.isObservingDiscovery() })
        await repository.sendDiscoveredBikes([first, second])
        #expect(await waitUntil { viewModel.viewState.discoveredBikes.count == 2 })
        viewModel.selectDiscoveredBike(second)

        #expect(viewModel.viewState.vin == second.vin)
        #expect(!viewModel.viewState.isDiscoveringBikes)
    }

}

private extension BikeOnboardingViewModelTests {
    func makeViewModel(
        repository: OnboardingRepository,
        profileRepository: OnboardingProfileRepository,
        bluetoothAuthorization: @escaping @MainActor @Sendable () -> BikeOnboardingBluetoothAuthorization = {
            .notDetermined
        }
    ) -> BikeOnboardingViewModel {
        BikeOnboardingViewModel(
            useCases: .init(
                start: .init(repository: repository),
                connect: .init(repository: repository),
                observeConnection: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                saveProfile: .init(repository: profileRepository)
            ),
            bluetoothAuthorization: bluetoothAuthorization
        )
    }

    func advanceToConnection(
        _ viewModel: BikeOnboardingViewModel,
        repository: OnboardingRepository
    ) async {
        viewModel.next()
        viewModel.next()
        await repository.sendConnection(.init(state: .idle))
        #expect(await waitUntil { viewModel.viewState.step == .identify })
        viewModel.next()
    }
}
