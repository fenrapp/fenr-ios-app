import BikeDomain
@testable import BikeOnboarding
import RuntimeConfiguration
import Testing
import TestSupport

@MainActor
@Suite("Bike onboarding success")
struct BikeOnboardingSuccessViewModelTests {
    @Test("Completes only after matching telemetry, profile persistence, and success presentation")
    func completesAfterTelemetryAndSuccessPresentation() async {
        let fixture = BikeOnboardingViewModelFixture()
        await advanceToConnectedBike(fixture)

        await fixture.repository.sendConnection(
            .init(state: .receivingTelemetry(peripheralName: "FENRTEST000000001"))
        )

        #expect(await waitUntil { fixture.viewModel.viewState.step == .success })
        #expect(await waitUntil { await fixture.profileRepository.loadProfile() != nil })
        #expect(fixture.completion.value() == nil)
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.successPresentationDelay
            ) == 1
        })

        await fixture.timing.resumeFirstSleep(
            for: FENRRuntimeConstants.Onboarding.successPresentationDelay
        )

        #expect(await waitUntil { fixture.completion.value() == "FENRTEST000000001" })
    }

    @Test("Waits for an explicit success action when VoiceOver is enabled")
    func voiceOverSuccessWaitsForExplicitContinuation() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.setVoiceOverEnabled(true)
        await advanceToConnectedBike(fixture)

        await fixture.repository.sendConnection(
            .init(state: .receivingTelemetry(peripheralName: "FENRTEST000000001"))
        )

        #expect(await waitUntil { fixture.viewModel.viewState.step == .success })
        #expect(await waitUntil { await fixture.profileRepository.saveCount() == 1 })
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.successPresentationDelay
        ) == 0)
        #expect(fixture.completion.value() == nil)

        fixture.viewModel.continueFromSuccess()

        #expect(await waitUntil { fixture.completion.value() == "FENRTEST000000001" })
        #expect(fixture.completion.count() == 1)
    }

    @Test("Ignores duplicate matching telemetry while completing")
    func matchingTelemetryCompletesOnlyOnce() async {
        let fixture = BikeOnboardingViewModelFixture()
        await advanceToConnectedBike(fixture)
        let telemetry = BikeConnection(
            state: .receivingTelemetry(peripheralName: "FENRTEST000000001")
        )

        await fixture.repository.sendConnection(telemetry)
        await fixture.repository.sendConnection(telemetry)

        #expect(await waitUntil { await fixture.profileRepository.saveCount() == 1 })
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.successPresentationDelay
            ) == 1
        })
        #expect(await fixture.timing.requestedSleepCount(
            for: FENRRuntimeConstants.Onboarding.successPresentationDelay
        ) == 1)

        await fixture.timing.resumeFirstSleep(
            for: FENRRuntimeConstants.Onboarding.successPresentationDelay
        )

        #expect(await waitUntil { fixture.completion.count() == 1 })
        #expect(await fixture.profileRepository.saveCount() == 1)
        #expect(fixture.completion.count() == 1)
    }

    private func advanceToConnectedBike(_ fixture: BikeOnboardingViewModelFixture) async {
        fixture.viewModel.startObserving()
        #expect(await waitUntil { await fixture.repository.isObservingConnection() })
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.isObservingDiscovery() })
        await fixture.repository.sendDiscoveredBikes([
            .init(vin: "FENRTEST000000001", rssi: -45)
        ])
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
            ) == 1
        })
        await fixture.timing.resumeFirstSleep(
            for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
        )
        #expect(await waitUntil { fixture.viewModel.viewState.step == .pairing })
        fixture.viewModel.copyAndPair()
        #expect(await waitUntil { await fixture.repository.connectedVIN() != nil })
    }
}
