import BikeDomain
@testable import BikeOnboarding
import RuntimeConfiguration
import Testing
import TestSupport

@MainActor
@Suite("Bike onboarding discovery")
struct BikeOnboardingDiscoveryViewModelTests {
    @Test("Stops discovery and offers recovery after no bikes are found")
    func timesOutDiscoveryWithoutResults() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 1
        })
        await fixture.repository.sendDiscoveredBikes([])
        await Task.yield()
        #expect(await fixture.timing.requestedSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        ) == 1)

        await fixture.timing.resumeFirstSleep(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        )

        #expect(await waitUntil { fixture.viewModel.viewState.discoveryState == .timedOut })
        #expect(!fixture.viewModel.viewState.isDiscoveringBikes)
        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })

        fixture.viewModel.retryDiscovery()

        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 2 })
        #expect(await waitUntil {
            await fixture.timing.requestedSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 2
        })
        #expect(fixture.viewModel.viewState.discoveryState == .scanning)
        #expect(fixture.viewModel.viewState.isDiscoveringBikes)
    }

    @Test("Finding a bike cancels the no-results timeout")
    func discoveredBikeCancelsTimeout() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 1
        })

        await fixture.repository.sendDiscoveredBikes([
            .init(vin: "FENRTEST000000001", rssi: -45)
        ])

        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 0
        })
        #expect(fixture.viewModel.viewState.discoveryState == .stabilizing)
        #expect(fixture.viewModel.viewState.isDiscoveringBikes)
    }

    @Test("Keeps the stabilization timer when only the candidate RSSI changes")
    func keepsSingleBikeStabilizationAcrossSignalUpdates() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.isObservingDiscovery() })

        await fixture.repository.sendDiscoveredBikes([
            .init(vin: "FENRTEST000000001", rssi: -45)
        ])
        #expect(await waitUntil {
            await fixture.timing.requestedSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
            ) == 1
        })

        await fixture.repository.sendDiscoveredBikes([
            .init(vin: "FENRTEST000000001", rssi: -61)
        ])
        await Task.yield()

        #expect(await fixture.timing.requestedSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
        ) == 1)
        await fixture.timing.resumeFirstSleep(
            for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
        )
        #expect(await waitUntil { fixture.viewModel.viewState.step == .pairing })
    }

    @Test("Stops the active scan before Scan Again starts another one")
    func serializesExplicitDiscoveryRetry() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 1
        })
        await fixture.repository.suspendDiscoveryStop()

        fixture.viewModel.retryDiscovery()

        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })
        #expect(await fixture.repository.discoveryStartCount() == 1)
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        ) == 0)
        await fixture.repository.resumeDiscoveryStop()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 2 })
        #expect(await waitUntil {
            await fixture.timing.requestedSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 2
        })
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        ) == 1)
        #expect(fixture.viewModel.viewState.discoveryState == .scanning)
        #expect(fixture.viewModel.viewState.isDiscoveringBikes)
    }

    @Test("Shows a typed discovery recovery state and stops scanning")
    func discoveryFailureStopsScanning() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.startObserving()
        #expect(await waitUntil { await fixture.repository.isObservingConnection() })
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })

        await fixture.repository.sendConnection(.init(state: .failed(message: "Discovery unavailable")))

        #expect(await waitUntil { fixture.viewModel.viewState.discoveryState == .failed })
        #expect(!fixture.viewModel.viewState.isDiscoveringBikes)
        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })
    }

    @Test("Bluetooth recovery stops discovery and its no-results timeout")
    func bluetoothRecoveryStopsDiscovery() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.startObserving()
        #expect(await waitUntil { await fixture.repository.isObservingConnection() })
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 1
        })

        await fixture.repository.sendConnection(.init(state: .bluetoothPoweredOff))

        #expect(await waitUntil { fixture.viewModel.viewState.step == .bluetooth })
        #expect(fixture.viewModel.viewState.bluetoothState == .poweredOff)
        #expect(!fixture.viewModel.viewState.isDiscoveringBikes)
        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        ) == 0)
    }

    @Test("Popping discovery returns to the hero and cannot be repushed by a late result")
    func discoveryBackStopsScanningWithoutRepush() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 1
        })

        fixture.viewModel.back()

        #expect(fixture.viewModel.viewState.step == .welcome)
        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        ) == 0)

        await fixture.repository.sendDiscoveredBikes([
            .init(vin: "FENRTEST000000001", rssi: -45)
        ])
        await Task.yield()

        #expect(fixture.viewModel.viewState.step == .welcome)
        #expect(fixture.viewModel.viewState.discoveredBikes.isEmpty)
        #expect(await fixture.repository.discoveryStopCount() == 1)

        fixture.viewModel.getStarted()

        #expect(fixture.viewModel.viewState.step == .discovery)
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 2 })
    }
}
