import BikeDomain
import Testing
import TestSupport
@testable import WatchOnboarding

@MainActor
struct WatchOnboardingViewModelTests {
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
        viewModel.select(.init(vin: "FENRTEST000000001", rssi: -45))
        await repository.sendConnection(.init(state: .receivingTelemetry(peripheralName: "Stark VARG")))

        #expect(await waitUntil { await completion.profile()?.vin == "FENRTEST000000001" })
        #expect(await repository.loadProfile()?.vin == "FENRTEST000000001")
        #expect(!viewModel.isConnecting)
        #expect(viewModel.errorMessage == nil)
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

        #expect(await waitUntil { viewModel.debugEvents.first?.title == "Error" })
        #expect(viewModel.debugEvents.first?.detail == "Security operation timed out: nonce read")
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
