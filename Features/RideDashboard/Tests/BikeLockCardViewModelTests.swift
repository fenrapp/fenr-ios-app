@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@Suite("Bike Lock card view model")
@MainActor
struct BikeLockCardViewModelTests {
    @Test("Prepares only after stationary telemetry and becomes available")
    func preparesWhenStationary() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()

        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(speed: 8))
        #expect(await fixture.repository.recordedPrepareRequests() == 0)
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())

        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })
        #expect(await fixture.repository.recordedPrepareRequests() == 1)
        #expect(fixture.capabilityStore.currentState == .init(
            vehicleIdentifier: BikeLockCardFixtures.vin,
            isAvailable: true
        ))
    }

    @Test("Keeps descriptive state disabled on disconnect and prepares again after reconnect")
    func repreparesAfterReconnect() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })

        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(
            connectionState: .disconnected(reason: nil)
        ))
        #expect(await waitUntil {
            fixture.viewModel.viewState.isAvailable
                && !fixture.viewModel.viewState.isActionEnabled
        })
        fixture.viewModel.performPrimaryAction()
        #expect(await fixture.repository.recordedLockRequests().isEmpty)
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())

        #expect(await waitUntil { await fixture.repository.recordedPrepareRequests() == 2 })
        #expect(fixture.viewModel.viewState.isAvailable)
        #expect(fixture.viewModel.viewState.isActionEnabled)
    }

    @Test("Suspending preserves status while dismissing and disabling control")
    func suspensionPreservesStatusAndDisablesControl() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })
        fixture.viewModel.performPrimaryAction()
        #expect(fixture.viewModel.viewState.sheet == .setup)

        fixture.viewModel.suspend()

        #expect(fixture.viewModel.viewState.isAvailable)
        #expect(!fixture.viewModel.viewState.isActionEnabled)
        #expect(fixture.viewModel.viewState.sheet == nil)
    }

    @Test("Suspending cancels an in-flight biometric authentication")
    func suspensionCancelsAuthentication() async {
        var settings = AppSettings()
        settings.setBikeLockSettings(
            .init(securityMode: .pinAndFaceID),
            forVIN: BikeLockCardFixtures.vin
        )
        let authenticator = SuspendedBikeLockCardAuthenticator()
        let fixture = BikeLockCardViewModelTestFactory.make(
            isLocked: true,
            settings: settings,
            authenticator: authenticator
        )
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })

        fixture.viewModel.performPrimaryAction()
        #expect(await waitUntil { await authenticator.hasPendingAuthentication() })
        fixture.viewModel.suspend()

        #expect(await waitUntil { await authenticator.recordedCancellationCount() == 1 })
        #expect(!fixture.viewModel.viewState.isActionEnabled)
        #expect(fixture.viewModel.viewState.sheet == nil)
        #expect(await fixture.repository.recordedLockRequests().isEmpty)
    }

    @Test("Revalidates stationary telemetry after biometric authentication")
    func rejectsUnlockWhenBikeMovesDuringAuthentication() async {
        var settings = AppSettings()
        settings.setBikeLockSettings(
            .init(securityMode: .pinAndFaceID),
            forVIN: BikeLockCardFixtures.vin
        )
        let authenticator = ControllableBikeLockCardAuthenticator()
        let fixture = BikeLockCardViewModelTestFactory.make(
            isLocked: true,
            settings: settings,
            authenticator: authenticator
        )
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })

        fixture.viewModel.performPrimaryAction()
        #expect(await waitUntil { await authenticator.hasPendingAuthentication() })
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(speed: 8, settings: settings))
        await authenticator.succeed()

        #expect(await waitUntil { fixture.viewModel.viewState.errorText != nil })
        #expect(await fixture.repository.recordedLockRequests().isEmpty)
        #expect(fixture.viewModel.viewState.isLocked)
    }

    @Test("No PIN protection does not force the dashboard card visible")
    func noPINConfigurationKeepsCardHidden() async {
        var settings = AppSettings()
        settings.dashboardCardConfiguration.setSectionVisibility(false, id: .bikeLock)
        let fixture = BikeLockCardViewModelTestFactory.make(settings: settings)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })

        fixture.viewModel.configure(
            securityOptionID: BikeLockSecurityMode.withoutPIN.rawValue,
            pin: ""
        )

        #expect(await waitUntil { await fixture.repository.recordedLockRequests() == [true] })
        let savedSettings = await fixture.settingsRepository.load()
        #expect(!savedSettings.dashboardCardConfiguration.section(id: .bikeLock).isVisible)
    }

    @Test("An externally locked bike unlocks without forcing setup")
    func unlocksExternallyLockedBikeWithoutSetup() async {
        let fixture = BikeLockCardViewModelTestFactory.make(isLocked: true)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })
        #expect(fixture.viewModel.viewState.actionTitle == "Unlock")

        fixture.viewModel.performPrimaryAction()

        #expect(fixture.viewModel.viewState.sheet == nil)
        #expect(await waitUntil { await fixture.repository.recordedLockRequests() == [false] })
        let savedSettings = await fixture.settingsRepository.load()
        #expect(savedSettings.bikeLockSettings(forVIN: BikeLockCardFixtures.vin).securityMode == .notConfigured)
    }

    @Test("Configures a numeric PIN and locks the bike")
    func configuresPINAndLocks() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })
        fixture.viewModel.performPrimaryAction()
        #expect(fixture.viewModel.viewState.sheet == .setup)

        fixture.viewModel.configure(
            securityOptionID: BikeLockSecurityMode.pin.rawValue,
            pin: "123456"
        )

        #expect(fixture.viewModel.viewState.sheet == nil)
        #expect(fixture.viewModel.viewState.isWorking)
        #expect(await waitUntil { await fixture.repository.recordedLockRequests() == [true] })
        #expect(await fixture.credentialStore.storedPIN(for: BikeLockCardFixtures.vin) == "123456")
        #expect(fixture.viewModel.viewState.isLocked)
    }

    @Test("Rejects non-ASCII and non-numeric PIN values at the view-model boundary")
    func rejectsInvalidPIN() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })

        fixture.viewModel.configure(
            securityOptionID: BikeLockSecurityMode.pin.rawValue,
            pin: "12a456"
        )

        #expect(fixture.viewModel.viewState.errorText == "Enter a 6-digit PIN")
        #expect(await fixture.repository.recordedLockRequests().isEmpty)
    }

    @Test("Keeps setup visible while stationary telemetry refreshes")
    func preservesSetupDuringTelemetryUpdates() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })

        fixture.viewModel.performPrimaryAction()
        #expect(fixture.viewModel.viewState.sheet == .setup)
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .withoutPIN), forVIN: BikeLockCardFixtures.vin)
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))

        #expect(await waitUntil { fixture.viewModel.viewState.actionTitle == "Lock" })
        #expect(fixture.viewModel.viewState.sheet == .setup)
    }

    @Test("PIN mode requires the stored PIN before unlocking")
    func verifiesPINBeforeUnlocking() async {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: BikeLockCardFixtures.vin)
        let fixture = BikeLockCardViewModelTestFactory.make(isLocked: true, settings: settings)
        await fixture.credentialStore.save(pin: "123456", for: BikeLockCardFixtures.vin)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })

        fixture.viewModel.performPrimaryAction()
        #expect(fixture.viewModel.viewState.sheet == .enterPIN)
        fixture.viewModel.submitPIN("654321")
        #expect(await waitUntil { fixture.viewModel.viewState.errorText == "Incorrect PIN" })
        #expect(await fixture.repository.recordedLockRequests().isEmpty)

        fixture.viewModel.submitPIN("123456")
        #expect(await waitUntil { await fixture.repository.recordedLockRequests() == [false] })
        #expect(!fixture.viewModel.viewState.isLocked)
    }
}
