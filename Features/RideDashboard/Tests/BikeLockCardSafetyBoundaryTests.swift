import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import TestSupport
import VehicleSession

@Suite("Bike Lock card safety boundaries")
@MainActor
struct BikeLockCardSafetyBoundaryTests {
    @Test("A stationary speed without bike status cannot enable a lock operation")
    func missingStatusDoesNotEnableLock() {
        let context = BikeLockCardVehicleContextMapper().map(.init(
            telemetry: .init(speed: .known(kmh: 0, kmhX10: 0), lastUpdated: Date()),
            connection: .init(state: .receivingTelemetry(peripheralName: "Test Bike")),
            resolvedSpeedKilometersPerHour: 0
        ))
        #expect(context.isReceivingTelemetry)
        #expect(!context.canPrepareNoOp)
        #expect(!context.canPerformLockWrite)
    }

    @Test("Rejects a preparation snapshot without confirmed no-op evidence")
    func noOpEvidenceIsRequiredToEnableControl() async {
        let fixture = BikeLockCardViewModelTestFactory.make(passesNoOpWrite: false)
        fixture.viewModel.start()

        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot())

        #expect(await waitUntil { await fixture.repository.recordedPrepareRequests() == 1 })
        #expect(fixture.viewModel.viewState.isAvailable)
        #expect(!fixture.viewModel.viewState.isActionEnabled)
        #expect(fixture.viewModel.viewState.statusText == "Status not confirmed")
        #expect(fixture.viewModel.viewState.errorText != nil)
    }

    @Test("Changing motorcycles clears the previous confirmed lock state")
    func vehicleChangeClearsConfirmedLockState() async {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: BikeLockCardFixtures.vin)
        let fixture = BikeLockCardViewModelTestFactory.make(isLocked: true, settings: settings)
        fixture.viewModel.start()
        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(settings: settings))
        #expect(await waitUntil { fixture.viewModel.viewState.isLocked })
        fixture.viewModel.performPrimaryAction()
        #expect(fixture.viewModel.viewState.sheet == .enterPIN)

        await fixture.vehicleSession.send(BikeLockCardFixtures.snapshot(
            vin: "FENRTEST000000002",
            speed: 8
        ))

        #expect(await waitUntil {
            fixture.viewModel.viewState.isAvailable
                && !fixture.viewModel.viewState.isLocked
                && fixture.viewModel.viewState.statusText == "Status not confirmed"
                && fixture.viewModel.viewState.sheet == nil
        })
    }
}
