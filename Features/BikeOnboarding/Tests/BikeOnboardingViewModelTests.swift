import BikeDomain
@testable import BikeOnboarding
import RuntimeConfiguration
import Testing
import TestSupport

@MainActor
@Suite("Bike onboarding view model")
struct BikeOnboardingViewModelTests {
    @Test("Normalizes an injected onboarding VIN")
    func normalizesInitialVIN() {
        let fixture = BikeOnboardingViewModelFixture(initialVIN: "fenrtest000000001")

        #expect(fixture.viewModel.viewState.vin == "FENRTEST000000001")
    }

    @Test("Skips the Bluetooth explainer when access is already allowed")
    func allowedBluetoothStartsDiscovery() async {
        let fixture = BikeOnboardingViewModelFixture()

        fixture.viewModel.getStarted()

        #expect(fixture.viewModel.viewState.step == .discovery)
        #expect(await waitUntil { await fixture.repository.startCount() == 1 })
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
    }

    @Test("Requests Bluetooth only after the explainer action")
    func requestsBluetoothContextually() async {
        let fixture = BikeOnboardingViewModelFixture(authorization: .notDetermined)
        fixture.viewModel.startObserving()
        #expect(await waitUntil { await fixture.repository.isObservingConnection() })

        fixture.viewModel.getStarted()
        #expect(fixture.viewModel.viewState.step == .bluetooth)
        #expect(await fixture.repository.startCount() == 0)

        fixture.viewModel.continueBluetooth()
        #expect(await waitUntil { await fixture.repository.startCount() == 1 })
        fixture.authorization.authorization = .allowed
        await fixture.repository.sendConnection(.init(state: .idle))

        #expect(await waitUntil { fixture.viewModel.viewState.step == .discovery })
        #expect(!fixture.viewModel.viewState.isRequestingBluetoothAccess)
    }

    @Test("Keeps denied Bluetooth access on a recoverable settings screen")
    func deniedBluetoothShowsSettings() {
        let fixture = BikeOnboardingViewModelFixture(authorization: .denied)

        fixture.viewModel.getStarted()

        #expect(fixture.viewModel.viewState.step == .bluetooth)
        #expect(fixture.viewModel.viewState.bluetoothState == .denied)
    }

    @Test("Automatically selects one bike only after discovery stabilizes")
    func selectsSingleBikeAfterStabilization() async {
        let fixture = BikeOnboardingViewModelFixture()
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
        #expect(fixture.viewModel.viewState.step == .discovery)

        await fixture.timing.resumeFirstSleep(
            for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
        )

        #expect(await waitUntil { fixture.viewModel.viewState.step == .pairing })
        #expect(fixture.viewModel.viewState.vin == "FENRTEST000000001")
        #expect(fixture.viewModel.viewState.pairingPIN == "654321")
    }

    @Test("Shows every nearby bike with model and signal when discovery is ambiguous")
    func mapsMultipleBikesForSelection() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.isObservingDiscovery() })

        await fixture.repository.sendDiscoveredBikes([
            .init(vin: "UDUMXTEST00000001", rssi: -58),
            .init(vin: "UDUEXTEST00000002", rssi: -43),
            .init(vin: "UDUSMTEST00000003", rssi: -75)
        ])

        #expect(await waitUntil { fixture.viewModel.viewState.discoveredBikes.count == 3 })
        #expect(fixture.viewModel.viewState.discoveredBikes.map(\.modelTitle) == [
            "VARG EX", "VARG MX", "VARG SM"
        ])
        #expect(fixture.viewModel.viewState.discoveredBikes.first?.rssiText == "-43 dBm")
        #expect(fixture.viewModel.viewState.discoveredBikes.first?.formattedVIN == "UDUE XTES T000 00002")
        #expect(fixture.viewModel.viewState.step == .discovery)
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryStabilizationDelay
        ) == 0)
    }

    @Test("Copy and Pair writes the PIN before starting a connection")
    func copiesPINBeforeConnection() async {
        let fixture = BikeOnboardingViewModelFixture()
        await advanceToPairing(fixture)

        fixture.viewModel.copyAndPair()

        #expect(fixture.clipboard.copiedStrings == ["654321"])
        #expect(fixture.viewModel.viewState.didCopyPIN)
        #expect(fixture.viewModel.viewState.step == .connecting)
        #expect(await waitUntil { await fixture.repository.connectedVIN() == "FENRTEST000000001" })
    }

    @Test("Canceling a connection disconnects before returning to discovery")
    func cancellationDisconnects() async {
        let fixture = BikeOnboardingViewModelFixture()
        await advanceToPairing(fixture)
        fixture.viewModel.copyAndPair()
        #expect(await waitUntil { await fixture.repository.connectedVIN() != nil })

        fixture.viewModel.cancelConnection()

        #expect(await waitUntil { await fixture.repository.disconnectCount() == 1 })
        #expect(await waitUntil { fixture.viewModel.viewState.step == .discovery })
        #expect(await fixture.repository.connectedVIN() == nil)
    }

    @Test("Ignores telemetry from a different bike")
    func ignoresMismatchedTelemetry() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.startObserving()
        #expect(await waitUntil { await fixture.repository.isObservingConnection() })
        await advanceToPairing(fixture)
        fixture.viewModel.copyAndPair()
        await fixture.repository.sendConnection(
            .init(state: .receivingTelemetry(peripheralName: "FENRTEST000000002"))
        )

        #expect(fixture.viewModel.viewState.step == .connecting)
        #expect(await fixture.profileRepository.loadProfile() == nil)
    }

    @Test("Serializes discovery restart behind a pending stop")
    func serializesDiscoveryRestart() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
        await fixture.repository.suspendDiscoveryStop()

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
        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })
        fixture.viewModel.back()
        #expect(await fixture.repository.discoveryStartCount() == 1)

        await fixture.repository.resumeDiscoveryStop()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 2 })
    }

    @Test("Leaving discovery stops scanning and tears down any partial connection")
    func stoppingObservationCleansUpBLEWork() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.getStarted()
        #expect(await waitUntil { await fixture.repository.discoveryStartCount() == 1 })
        #expect(await waitUntil {
            await fixture.timing.pendingSleepCount(
                for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
            ) == 1
        })

        fixture.viewModel.stopObserving()

        #expect(await waitUntil { await fixture.repository.discoveryStopCount() == 1 })
        #expect(await waitUntil { await fixture.repository.disconnectCount() == 1 })
        #expect(await fixture.timing.pendingSleepCount(
            for: FENRRuntimeConstants.Onboarding.discoveryNoResultsTimeout
        ) == 0)
    }

    @Test("Exposes pairing reset and Bluetooth failures as specific recovery states")
    func mapsRecoverableConnectionFailures() async {
        let fixture = BikeOnboardingViewModelFixture()
        fixture.viewModel.startObserving()
        #expect(await waitUntil { await fixture.repository.isObservingConnection() })
        await advanceToPairing(fixture)
        fixture.viewModel.copyAndPair()

        await fixture.repository.sendConnection(
            .init(state: .pairingResetRequired(message: "Remove the previous pairing and try again."))
        )
        #expect(await waitUntil {
            fixture.viewModel.viewState.connectionState == .pairingResetRequired
        })

        await fixture.repository.sendConnection(.init(state: .failed(message: "Bike connection timed out")))
        #expect(await waitUntil { fixture.viewModel.viewState.connectionState == .timedOut })

        await fixture.repository.sendConnection(.init(state: .failed(message: "Security authentication failed")))
        #expect(await waitUntil {
            fixture.viewModel.viewState.connectionState == .authenticationFailed
        })

        await fixture.repository.sendConnection(.init(state: .disconnected(reason: "Private transport detail")))
        #expect(await waitUntil { fixture.viewModel.viewState.connectionState == .disconnected })

        await fixture.repository.sendConnection(.init(state: .bluetoothUnauthorized))
        #expect(await waitUntil { fixture.viewModel.viewState.step == .bluetooth })
        #expect(fixture.viewModel.viewState.bluetoothState == .denied)

        await fixture.repository.sendConnection(.init(state: .bluetoothPoweredOff))
        #expect(await waitUntil { fixture.viewModel.viewState.bluetoothState == .poweredOff })
        #expect(fixture.viewModel.viewState.step == .bluetooth)

        await fixture.repository.sendConnection(.init(state: .bluetoothUnavailable))
        #expect(await waitUntil { fixture.viewModel.viewState.bluetoothState == .unavailable })
        #expect(fixture.viewModel.viewState.step == .bluetooth)
    }

    private func advanceToPairing(_ fixture: BikeOnboardingViewModelFixture) async {
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
    }
}
