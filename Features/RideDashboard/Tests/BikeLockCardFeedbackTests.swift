@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport

@Suite("Bike Lock sheet feedback")
@MainActor
struct BikeLockCardFeedbackTests {
    @Test("Setup failure remains visible during telemetry and a successful retry dismisses it")
    func setupFailureSurvivesTelemetryAndRetry() async {
        let fixture = BikeLockCardViewModelTestFactory.make()
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })
        fixture.viewModel.performPrimaryAction()
        await fixture.credentialStore.setFailsSaving(true)

        fixture.viewModel.configure(securityOptionID: "pin", pin: "123456")

        #expect(fixture.viewModel.viewState.sheet == .setup)
        #expect(fixture.viewModel.viewState.isWorking)
        #expect(await waitUntil { fixture.viewModel.viewState.errorText != nil })
        let error = fixture.viewModel.viewState.errorText
        #expect(!fixture.viewModel.viewState.isWorking)
        #expect(await fixture.repository.recordedLockRequests().isEmpty)
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(speed: 8))
        #expect(await waitUntil { !fixture.viewModel.isVehicleStationary })
        #expect(fixture.viewModel.viewState.errorText == error)
        #expect(fixture.viewModel.viewState.sheet == .setup)

        await fixture.credentialStore.setFailsSaving(false)
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })
        fixture.viewModel.configure(securityOptionID: "pin", pin: "123456")
        #expect(fixture.viewModel.viewState.errorText == nil)
        #expect(await waitUntil { fixture.viewModel.viewState.isLocked })
        #expect(fixture.viewModel.viewState.sheet == nil)
        #expect(!fixture.viewModel.viewState.isWorking)
        fixture.viewModel.stop()
    }

    @Test("Incorrect PIN persists through telemetry until the next completed PIN attempt")
    func incorrectPINSurvivesTelemetryAndClearsAfterSuccess() async throws {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: BikeLockCardFixtures.vin)
        let fixture = BikeLockCardViewModelTestFactory.make(isLocked: true, settings: settings)
        try await fixture.credentialStore.save(pin: "123456", for: BikeLockCardFixtures.vin)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })
        fixture.viewModel.performPrimaryAction()
        fixture.viewModel.submitPIN("654321")
        #expect(await waitUntil { fixture.viewModel.viewState.errorText == "Incorrect PIN" })

        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(speed: 8, settings: settings))
        #expect(await waitUntil { !fixture.viewModel.isVehicleStationary })
        #expect(fixture.viewModel.viewState.errorText == "Incorrect PIN")
        #expect(fixture.viewModel.viewState.sheet == .enterPIN)
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })
        fixture.viewModel.submitPIN("123456")
        #expect(fixture.viewModel.viewState.errorText == nil)
        #expect(await waitUntil { !fixture.viewModel.viewState.isLocked })
        #expect(fixture.viewModel.viewState.sheet == nil)
        fixture.viewModel.stop()
    }

    @Test("Telemetry cannot reenable a pending authentication control")
    func pendingControlRemainsDisabledDuringTelemetry() async {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pinAndFaceID), forVIN: BikeLockCardFixtures.vin)
        let authenticator = ControllableBikeLockCardAuthenticator()
        let fixture = BikeLockCardViewModelTestFactory.make(
            isLocked: true, settings: settings, authenticator: authenticator
        )
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isActionEnabled })
        fixture.viewModel.performPrimaryAction()
        #expect(await waitUntil { await authenticator.hasPendingAuthentication() })

        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(speed: 8, settings: settings))
        #expect(await waitUntil { !fixture.viewModel.isVehicleStationary })
        #expect(fixture.viewModel.viewState.isWorking)
        #expect(!fixture.viewModel.viewState.isActionEnabled)
        fixture.viewModel.stop()
        #expect(await waitUntil { !(await authenticator.hasPendingAuthentication()) })
    }
}
