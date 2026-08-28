import BikeDomain
@testable import ChargeControl
import Testing
import TestSupport

@MainActor
@Suite("Charge control session")
struct ChargeControlSessionTests {
    @Test("Repeated telemetry prepares only once")
    func repeatedTelemetryPreparesOnlyOnce() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(repository: repository)
        let health = ChargeControlFixtures.chargingHealth()

        session.receive(health)
        session.receive(health)

        #expect(await waitUntil { await repository.prepareCount() == 1 })
        #expect(session.state.isEnabled)
    }

    @Test("Disconnect resets preparation for the next connection")
    func disconnectAllowsPreparationAfterReconnect() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(repository: repository)

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { await repository.prepareCount() == 1 })
        session.receive(BikeBatteryHealth())
        session.receive(ChargeControlFixtures.chargingHealth())

        #expect(await waitUntil { await repository.prepareCount() == 2 })
        #expect(session.state.isEnabled)
    }

    @Test("Disconnect cancels preparation before a new connection is prepared")
    func disconnectCancelsPreparation() async {
        let repository = ChargeControlRepository(preparationDelay: .milliseconds(100))
        let session = ChargeControlSessionTestFactory.make(repository: repository)

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { await repository.prepareCount() == 1 })
        session.receive(BikeBatteryHealth())

        #expect(await waitUntil { await repository.cancelledPreparationCount() == 1 })
        #expect(session.state.phase == .unavailable)

        session.receive(ChargeControlFixtures.chargingHealth())

        #expect(await waitUntil { await repository.prepareCount() == 2 })
        #expect(await waitUntil { session.state.isEnabled })
    }

    @Test("A second power selection is ignored while the first update is pending")
    func pendingPowerUpdateRejectsAnotherSelection() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(20)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 1_200)
        session.setPowerLimit(watts: 1_300)

        #expect(await waitUntil { await repository.writtenPowerValues() == [1_200] })
        #expect(session.state.selectedWatts == 1_200)
        #expect(!session.state.canAcceptInput)
    }

    @Test("The production debounce waits at least one second")
    func defaultDebounceWaitsOneSecond() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(repository: repository)
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 1_500)
        try? await Task.sleep(for: .milliseconds(900))

        #expect(await repository.writtenPowerValues().isEmpty)
        #expect(await waitUntil(timeout: .milliseconds(300)) {
            await repository.writtenPowerValues() == [1_500]
        })
    }

    @Test("Selecting confirmed values does not enter updating or write")
    func confirmedValuesSkipUpdatingAndWrites() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 1_000)
        session.setTarget(percent: 100)

        #expect(session.state.phase == .ready)
        try? await Task.sleep(for: .milliseconds(30))

        #expect(await repository.writtenPowerValues().isEmpty)
        #expect(await repository.writtenTargetValues().isEmpty)
        #expect(session.state.phase == .ready)
        #expect(session.state.selectedWatts == 1_000)
        #expect(session.state.selectedTargetPercent == 100)
    }

    @Test("Power confirmation blocks both controls until telemetry confirms it")
    func powerConfirmationBlocksBothControls() async {
        let repository = ChargeControlRepository()
        await repository.suspendPowerWrites()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10),
            confirmationDelay: .seconds(1)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 1_500)
        #expect(await waitUntil { await repository.writtenPowerValues() == [1_500] })
        session.setTarget(percent: 80)
        try? await Task.sleep(for: .milliseconds(30))

        #expect(await repository.writtenTargetValues().isEmpty)
        #expect(await repository.maximumConcurrentWriteCount() == 1)
        #expect(!session.state.canAcceptInput)

        await repository.resumePowerWrites()
        #expect(await waitUntil { session.state.status == "Confirming 1500 W" })
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 1_500))

        #expect(await waitUntil { session.state.canAcceptInput })
        #expect(await repository.writtenTargetValues().isEmpty)
        session.setTarget(percent: 80)
        #expect(await waitUntil { await repository.writtenTargetValues() == [80] })
        #expect(await repository.maximumConcurrentWriteCount() == 1)
    }

    @Test("Telemetry received before write completion still confirms the write")
    func earlyTelemetryConfirmsWrite() async {
        let repository = ChargeControlRepository()
        await repository.suspendPowerWrites()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10),
            confirmationDelay: .milliseconds(30)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 1_500)
        #expect(await waitUntil { await repository.writtenPowerValues() == [1_500] })
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 1_500))
        await repository.resumePowerWrites()

        #expect(await waitUntil { session.state.phase == .ready })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(session.state.phase == .ready)
        #expect(session.state.error == nil)
        #expect(session.state.confirmedWatts == 1_500)
    }

    @Test("Confirming a write rejects a newer selection until confirmation")
    func pendingConfirmationRejectsNewerSelection() async {
        let repository = ChargeControlRepository()
        await repository.suspendPowerWrites()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10),
            confirmationDelay: .seconds(1)
        )
        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 1_500)
        #expect(await waitUntil { await repository.writtenPowerValues() == [1_500] })
        session.setPowerLimit(watts: 1_700)
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 1_500))
        #expect(session.state.selectedWatts == 1_500)

        await repository.resumePowerWrites()

        #expect(await waitUntil { session.state.phase == .ready })
        #expect(await repository.writtenPowerValues() == [1_500])
        #expect(session.state.selectedWatts == 1_500)
        #expect(session.state.canAcceptInput)
    }

    @Test("Disconnect cancels a pending debounced write")
    func disconnectCancelsPendingWrite() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(50),
            confirmationDelay: .milliseconds(50)
        )

        session.receive(ChargeControlFixtures.chargingHealth())
        #expect(await waitUntil { session.state.isEnabled })
        session.setTarget(percent: 80)
        session.receive(BikeBatteryHealth())
        try? await Task.sleep(for: .milliseconds(100))

        #expect(await repository.writtenTargetValues().isEmpty)
        #expect(session.state.phase == .unavailable)
        #expect(!session.state.isVisible)
    }

    @Test("Inputs retain the validated clamps and steps")
    func inputsUseValidatedRangesAndSteps() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(
            repository: repository,
            debounceDelay: .milliseconds(10)
        )
        session.receive(ChargeControlFixtures.chargingHealth(chargerType: .backpack))
        #expect(await waitUntil { session.state.isEnabled })

        session.setPowerLimit(watts: 349)
        #expect(await waitUntil { await repository.writtenPowerValues() == [300] })
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 300))
        session.setPowerLimit(watts: 9_999)
        #expect(await waitUntil { await repository.writtenPowerValues() == [300, 3_300] })
        session.receive(ChargeControlFixtures.chargingHealth(powerWatts: 3_300))
        session.setTarget(percent: 0)
        #expect(await waitUntil { await repository.writtenTargetValues() == [1] })

        #expect(session.state.minimumWatts == 300)
        #expect(session.state.maximumWatts == 3_300)
        #expect(session.state.stepWatts == 100)
        #expect(session.state.minimumTargetPercent == 1)
        #expect(session.state.maximumTargetPercent == 100)
        #expect(session.state.targetStepPercent == 1)
    }

    @Test("Fast charger retains its validated maximum")
    func fastChargerUsesValidatedMaximum() async {
        let repository = ChargeControlRepository()
        let session = ChargeControlSessionTestFactory.make(repository: repository)

        session.receive(ChargeControlFixtures.chargingHealth(chargerType: .fast))
        #expect(await waitUntil { session.state.isEnabled })

        #expect(session.state.minimumWatts == 300)
        #expect(session.state.maximumWatts == 7_000)
        #expect(session.state.stepWatts == 100)
    }
}
