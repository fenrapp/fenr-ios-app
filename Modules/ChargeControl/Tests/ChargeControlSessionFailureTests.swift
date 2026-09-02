import BikeDomain
@testable import ChargeControl
import Testing
import TestSupport

@MainActor
@Suite("Charge control failures")
struct ChargeControlSessionFailureTests {
    @Test("Incompatible firmware disables writes even when no-op passes")
    func incompatibleFirmwareDisablesWritesEvenWhenNoOpPasses() async {
        let repository = ChargeControlRepository(
            isFirmwareCompatible: false,
            passesNoOpWrite: true
        )
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10)
        )

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.phase == .failed })

        #expect(session.state.isVisible)
        #expect(!session.state.isEnabled)
        #expect(session.state.status == .unsupportedFirmware)
        #expect(session.state.failure == .incompatibleFirmware)

        session.setPowerLimit(watts: 1_500)
        session.setTarget(percent: 80)

        #expect(await repository.writtenPowerValues().isEmpty)
        #expect(await repository.writtenTargetValues().isEmpty)
    }

    @Test("A failed no-op guard keeps writes disabled")
    func failedNoOpGuardDisablesWrites() async {
        let repository = ChargeControlRepository(passesNoOpWrite: false)
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10)
        )

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.phase == .failed })
        session.setPowerLimit(watts: 1_500)
        try? await Task.sleep(for: .milliseconds(30))

        #expect(!session.state.isEnabled)
        #expect(await repository.writtenPowerValues().isEmpty)
    }

    @Test("Unconfirmed power restores telemetry after confirmation timeout")
    func unconfirmedPowerRestoresConfirmedValue() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10),
            confirmationDelay: .milliseconds(20)
        )

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })
        session.setPowerLimit(watts: 1_500)

        #expect(await waitUntil { await repository.writtenPowerValues() == [1_500] })
        #expect(await waitUntil { session.state.phase == .failed })
        #expect(session.state.selectedWatts == 1_000)
        #expect(session.state.failure == .confirmationTimedOut)
    }

    @Test("Rejected power write restores the confirmed value")
    func rejectedPowerWriteRestoresConfirmedValue() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })
        await repository.rejectPowerWrites()

        session.setPowerLimit(watts: 1_500)

        #expect(await waitUntil { session.state.phase == .failed })
        #expect(session.state.selectedWatts == 1_000)
        #expect(session.state.confirmedWatts == 1_000)
        #expect(session.state.failure == .writeFailed)
    }

    @Test("Unconfirmed target restores telemetry after confirmation timeout")
    func unconfirmedTargetRestoresConfirmedValue() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10),
            confirmationDelay: .milliseconds(20)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setTarget(percent: 80)

        #expect(await waitUntil { await repository.writtenTargetValues() == [80] })
        #expect(await waitUntil { session.state.phase == .failed })
        #expect(session.state.selectedTargetPercent == 100)
        #expect(session.state.confirmedTargetPercent == 100)
        #expect(session.state.failure == .confirmationTimedOut)
    }

    @Test("Reconnect cancels the previous connection confirmation timeout")
    func reconnectCancelsStaleConfirmation() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10),
            confirmationDelay: .milliseconds(40)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })
        session.setPowerLimit(watts: 1_500)
        #expect(await waitUntil { session.state.status == .confirming(.powerWatts(1_500)) })

        session.receive(BikeBatteryHealth())
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil {
            let prepareCount = await repository.prepareCount()
            return prepareCount == 2 && session.state.isEnabled
        })
        try? await Task.sleep(for: .milliseconds(60))

        #expect(session.state.phase == .ready)
        #expect(session.state.failure == nil)
        #expect(session.state.selectedWatts == 1_000)
    }
}
