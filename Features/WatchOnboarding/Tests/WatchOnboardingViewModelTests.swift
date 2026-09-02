import BikeDomain
import Testing
import TestSupport
@testable import WatchOnboarding

@MainActor
struct WatchOnboardingViewModelTests {
    @Test("default state uses catalog-backed discovery copy")
    func defaultStateUsesLocalizedDiscoveryCopy() {
        let state = WatchOnboardingViewState()

        #expect(state.detail == String(localized: .watchOnboardingSearching))
    }

    @Test("Completes after telemetry starts for the selected bike")
    func completesAfterTelemetryStartsForSelectedBike() async {
        let repository = WatchOnboardingRepository()
        let completion = WatchOnboardingCompletionRecorder()
        let viewModel = WatchOnboardingViewModel(
            useCases: .init(
                connectToBike: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeDebugEvents: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                saveProfile: .init(repository: repository)
            ),
            onCompleted: { profile in
                Task { await completion.record(profile) }
            }
        )

        viewModel.start()
        viewModel.select(.init(vin: "FENRTEST000000001", signalText: "Signal -45 dBm"))
        await repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "Stark VARG")))

        #expect(await waitUntil { await completion.profile()?.vin == "FENRTEST000000001" })
        #expect(await repository.loadProfile()?.vin == "FENRTEST000000001")
        #expect(!viewModel.viewState.isConnecting)
        #expect(viewModel.viewState.errorMessage == nil)
    }

    @Test("Shows recent debug events while connecting")
    func showsRecentDebugEventsWhileConnecting() async {
        let repository = WatchOnboardingRepository()
        let viewModel = WatchOnboardingViewModel(
            useCases: .init(
                connectToBike: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeDebugEvents: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                saveProfile: .init(repository: repository)
            ),
            onCompleted: { _ in }
        )

        viewModel.start()
        await repository.sendDebugEvent(.init(title: "Error", detail: "Security operation timed out: nonce read"))

        #expect(await waitUntil { viewModel.viewState.debugEvents.first?.title == "Error" })
        #expect(viewModel.viewState.debugEvents.first?.detail == "Security operation timed out: nonce read")
    }

    @Test("Maps nearby bikes into display-ready signal rows")
    func mapsNearbyBikeRows() async {
        let repository = WatchOnboardingRepository()
        let viewModel = WatchOnboardingViewModel(
            useCases: .init(
                connectToBike: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeDebugEvents: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                saveProfile: .init(repository: repository)
            ),
            onCompleted: { _ in }
        )

        viewModel.start()
        await repository.sendDiscoveredBikes([
            .init(vin: "FENRTEST000000001", rssi: -65),
            .init(vin: "FENRTEST000000002", rssi: -45)
        ])

        #expect(await waitUntil { viewModel.viewState.discoveredBikes.count == 2 })
        #expect(viewModel.viewState.discoveredBikes.first?.vin == "FENRTEST000000002")
        #expect(viewModel.viewState.discoveredBikes.first?.signalText == "Signal -45 dBm")
    }

    @Test("Waits for discovery shutdown before restarting")
    func serializesDiscoveryRestart() async throws {
        let repository = WatchOnboardingRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()
        #expect(await waitUntil { await repository.discoveryStartCount() == 1 })
        await repository.suspendDiscoveryStop()

        viewModel.stop()
        #expect(await waitUntil { await repository.discoveryStopCount() == 1 })
        viewModel.start()
        try await Task.sleep(for: .milliseconds(50))
        #expect(await repository.discoveryStartCount() == 1)

        await repository.resumeDiscoveryStop()
        #expect(await waitUntil { await repository.discoveryStartCount() == 2 })
    }

    @Test("Connection failures do not expose transport details")
    func hidesConnectionFailureDetails() async {
        let repository = WatchOnboardingRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.start()

        await repository.sendConnection(.init(state: .failed(message: "transport detail")))
        #expect(await waitUntil {
            viewModel.viewState.errorMessage == String(localized: .watchOnboardingUnableToConnect)
        })

        await repository.sendConnection(.init(
            state: .pairingResetRequired(message: "transport detail")
        ))
        #expect(await waitUntil {
            viewModel.viewState.errorMessage == String(localized: .watchOnboardingPairAgain)
        })
        #expect(!(viewModel.viewState.errorMessage ?? "").contains("transport detail"))
        viewModel.stop()
    }

    private func makeViewModel(repository: WatchOnboardingRepository) -> WatchOnboardingViewModel {
        WatchOnboardingViewModel(
            useCases: .init(
                connectToBike: .init(repository: repository),
                observeConnection: .init(repository: repository),
                observeDebugEvents: .init(repository: repository),
                observeDiscoveredBikes: .init(repository: repository),
                startDiscovery: .init(repository: repository),
                stopDiscovery: .init(repository: repository),
                saveProfile: .init(repository: repository)
            ),
            onCompleted: { _ in }
        )
    }
}

private actor WatchOnboardingCompletionRecorder {
    private var completedProfile: BikeProfile?

    func record(_ profile: BikeProfile) {
        completedProfile = profile
    }

    func profile() -> BikeProfile? {
        completedProfile
    }
}
