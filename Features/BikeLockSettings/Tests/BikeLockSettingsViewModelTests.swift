@testable import BikeLockSettings
import SettingsDomain
import Testing
import TestSupport

@Suite("Bike Lock settings")
@MainActor
struct BikeLockSettingsViewModelTests {
    @Test("Changes local protection without a vehicle write dependency")
    func changesToNoPIN() async {
        let fixture = BikeLockSettingsViewModelFixture()
        await fixture.start()

        fixture.viewModel.changeProtection()
        #expect(fixture.viewModel.viewState.destination == .chooseProtection)
        fixture.viewModel.select(.withoutPIN)

        #expect(await waitUntil { fixture.viewModel.viewState.currentModeTitle == "No PIN" })
        let storedMode = await fixture.repository.load()
            .bikeLockSettings(forVIN: fixture.vin)
            .securityMode
        #expect(storedMode == .withoutPIN)
    }

    @Test("Current PIN protects a PIN change")
    func changesPINAfterVerification() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pin, pin: "123456")
        await fixture.start()

        fixture.viewModel.changePIN()
        #expect(fixture.viewModel.viewState.destination == .verifyCurrentPIN)
        fixture.viewModel.submitCurrentPIN("654321")
        #expect(await waitUntil { fixture.viewModel.viewState.errorMessage == "Incorrect PIN" })
        #expect(fixture.viewModel.viewState.destination == .verifyCurrentPIN)
        fixture.viewModel.submitCurrentPIN("123456")
        #expect(await waitUntil { fixture.viewModel.viewState.destination == .changePIN })
        fixture.viewModel.saveNewPIN("111222", confirmation: "111222")

        #expect(await waitUntil { await fixture.credentialStore.storedPIN(for: fixture.vin) == "111222" })
    }

    @Test("Cancelled Face ID falls back to the current PIN")
    func faceIDFallsBackToPIN() async {
        let fixture = BikeLockSettingsViewModelFixture(
            mode: .pinAndFaceID,
            pin: "123456",
            authenticatorOutcome: .success(false)
        )
        await fixture.start()

        fixture.viewModel.changeProtection()

        #expect(await waitUntil { fixture.viewModel.viewState.destination == .verifyCurrentPIN })
    }

    @Test("An incompatible VCU hides Bike Lock settings")
    func incompatibleBikeIsUnavailable() async {
        let fixture = BikeLockSettingsViewModelFixture(isAvailable: false)
        fixture.viewModel.start()
        await fixture.sendSnapshot(vin: fixture.vin)

        #expect(!fixture.viewModel.viewState.isAvailable)
    }

    @Test("Face ID opens protection selection")
    func faceIDOpensProtectionSelection() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pinAndFaceID, pin: "123456")
        await fixture.start()

        fixture.viewModel.changeProtection()

        #expect(await waitUntil { fixture.viewModel.viewState.destination == .chooseProtection })
    }

    @Test("A missing credential shows an error")
    func missingCredentialShowsError() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pinAndFaceID)
        await fixture.start()

        fixture.viewModel.changeProtection()

        #expect(await waitUntil {
            fixture.viewModel.viewState.errorMessage == "The saved PIN is unavailable."
        })
        #expect(fixture.viewModel.viewState.destination == nil)
    }

    @Test("Capability changes update availability")
    func capabilityChangesUpdateAvailability() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pinAndFaceID, pin: "123456")
        await fixture.authenticator.block()
        await fixture.start()
        #expect(fixture.capabilityStore.observerCount == 1)
        fixture.viewModel.changeProtection()
        #expect(await waitUntil { await fixture.authenticator.callCount() == 1 })

        fixture.capabilityStore.update(.init(vehicleIdentifier: fixture.vin, isAvailable: false))
        await fixture.authenticator.release()
        #expect(await waitUntil { !fixture.viewModel.viewState.isAvailable })
        #expect(!fixture.viewModel.viewState.isWorking)
        #expect(fixture.viewModel.viewState.destination == nil)
        fixture.capabilityStore.update(.init(vehicleIdentifier: fixture.vin, isAvailable: true))

        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })
    }

    @Test("An unavailable bike rejects changes")
    func unavailableBikeRejectsChanges() async {
        let fixture = BikeLockSettingsViewModelFixture(isAvailable: false)
        fixture.viewModel.start()
        await fixture.sendSnapshot(vin: fixture.vin)

        fixture.viewModel.changeProtection()
        fixture.viewModel.changePIN()
        fixture.viewModel.select(.withoutPIN)
        fixture.viewModel.saveNewPIN("123456", confirmation: "123456", optionID: .pin)

        #expect(fixture.viewModel.viewState.destination == nil)
        #expect(await fixture.repository.saveCount() == 0)
    }

    @Test("A vehicle change discards pending authentication")
    func vehicleChangeDiscardsPendingAuthentication() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pinAndFaceID, pin: "123456")
        await fixture.authenticator.block()
        await fixture.start()
        fixture.viewModel.changeProtection()
        #expect(await waitUntil { await fixture.authenticator.callCount() == 1 })

        await fixture.sendSnapshot(vin: BikeLockSettingsViewModelFixture.alternateVIN)
        await fixture.authenticator.release()

        #expect(await waitUntil { !fixture.viewModel.viewState.isWorking })
        #expect(fixture.viewModel.viewState.destination == nil)
        #expect(!fixture.viewModel.viewState.isAvailable)
    }

    @Test("Recovery closes sensitive UI and rejects actions")
    func recoveryInvalidatesSensitiveContext() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pinAndFaceID, pin: "123456")
        await fixture.authenticator.block()
        await fixture.start()
        fixture.viewModel.changeProtection()
        #expect(await waitUntil { await fixture.authenticator.callCount() == 1 })

        await fixture.sendSnapshot(
            vin: fixture.vin,
            isCanonicalTelemetryAvailable: false
        )

        #expect(await waitUntil { !fixture.viewModel.viewState.isAvailable })
        #expect(fixture.viewModel.viewState.destination == nil)
        fixture.viewModel.changeProtection()
        #expect(await fixture.authenticator.callCount() == 1)
        await fixture.authenticator.release()
    }

    @Test("Cancellation releases the current operation")
    func cancellationErrorReleasesOperation() async {
        let fixture = BikeLockSettingsViewModelFixture(
            mode: .pinAndFaceID,
            pin: "123456",
            authenticatorOutcome: .cancellation
        )
        await fixture.start()

        fixture.viewModel.changeProtection()
        #expect(await waitUntil { !fixture.viewModel.viewState.isWorking })
        #expect(fixture.viewModel.viewState.errorMessage == nil)
        await fixture.authenticator.setOutcome(.success(true))
        fixture.viewModel.changeProtection()

        #expect(await waitUntil { fixture.viewModel.viewState.destination == .chooseProtection })
    }

    @Test("Stopping cancels authentication and allows restart")
    func stopCancelsPendingAuthenticationAndCanRestart() async {
        let fixture = BikeLockSettingsViewModelFixture(mode: .pinAndFaceID, pin: "123456")
        await fixture.authenticator.block()
        await fixture.start()
        fixture.viewModel.changeProtection()
        #expect(await waitUntil { await fixture.authenticator.callCount() == 1 })

        fixture.viewModel.stop()
        await fixture.authenticator.setOutcome(.success(true))
        await fixture.authenticator.release()
        fixture.viewModel.start()
        await fixture.sendSnapshot(vin: fixture.vin)
        #expect(await waitUntil { fixture.viewModel.viewState.isAvailable })
        fixture.viewModel.changeProtection()

        #expect(await waitUntil { fixture.viewModel.viewState.destination == .chooseProtection })
        #expect(await fixture.authenticator.callCount() == 2)
    }

    @Test("Mismatched PIN confirmation does not persist")
    func mismatchedPINConfirmationDoesNotPersist() async {
        let fixture = BikeLockSettingsViewModelFixture()
        await fixture.start()
        fixture.viewModel.changeProtection()

        fixture.viewModel.select(.pin)
        #expect(await fixture.repository.saveCount() == 0)

        fixture.viewModel.saveNewPIN("123456", confirmation: "654321", optionID: .pin)

        #expect(fixture.viewModel.viewState.errorMessage == "The PINs do not match.")
        #expect(fixture.viewModel.viewState.destination == .chooseProtection)
        #expect(await fixture.repository.saveCount() == 0)
        #expect(await fixture.credentialStore.storedPIN(for: fixture.vin) == nil)
    }

    @Test("Credential failures use safe presentation copy")
    func credentialFailureUsesSafePresentationCopy() async {
        let fixture = BikeLockSettingsViewModelFixture()
        await fixture.start()
        await fixture.credentialStore.failWrites()
        fixture.viewModel.changeProtection()

        fixture.viewModel.saveNewPIN("123456", confirmation: "123456", optionID: .pin)

        #expect(await waitUntil {
            fixture.viewModel.viewState.errorMessage
                == "Unable to update Bike Lock settings. Try again."
        })
        #expect(fixture.viewModel.viewState.errorMessage?.contains("Failure") == false)
    }
}
