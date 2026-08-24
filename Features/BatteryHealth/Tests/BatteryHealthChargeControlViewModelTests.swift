@testable import BatteryHealth
import BikeDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Battery Health charge control view model")
struct BatteryHealthChargeControlViewModelTests {
    @Test("Charge power dragging does not write until release debounce")
    func chargePowerDraggingDoesNotWriteUntilRelease() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargePowerDrag()
        viewModel.setDisplayedChargePower(watts: 2_500)
        #expect(await repository.chargePowerWrites().isEmpty)

        viewModel.endChargePowerDrag()
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [2_500] })
        viewModel.stop()
    }

    @Test("Charge power rapid releases produce one final debounced write")
    func chargePowerRapidReleasesProduceOneFinalWrite() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setDisplayedChargePower(watts: 2_000)
        viewModel.endChargePowerDrag()
        viewModel.beginChargePowerDrag()
        viewModel.setDisplayedChargePower(watts: 2_700)
        viewModel.endChargePowerDrag()

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [2_700] })
        viewModel.stop()
    }

    @Test("Charge power release keeps optimistic value while old telemetry arrives")
    func chargePowerReleaseKeepsOptimisticValue() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargePowerDrag()
        viewModel.setDisplayedChargePower(watts: 1_500)
        viewModel.endChargePowerDrag()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)

        #expect(await waitUntil {
            viewModel.viewState.chargePowerControl.selectedWatts == 1_500
        })
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [1_500] })
        viewModel.stop()
    }

    @Test("Charge power dragging ignores stale telemetry")
    func chargePowerDraggingIgnoresStaleTelemetry() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargePowerDrag()
        viewModel.setDisplayedChargePower(watts: 2_200)
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)

        #expect(await waitUntil {
            viewModel.viewState.chargePowerControl.selectedWatts == 2_200
        })
        #expect(await repository.chargePowerWrites().isEmpty)
        viewModel.stop()
    }

    @Test("Charge power confirmed value is not written again")
    func chargePowerSameAsConfirmedSkipsWrite() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setDisplayedChargePower(watts: 1_000)
        viewModel.endChargePowerDrag()

        try? await Task.sleep(for: .milliseconds(1_200))
        #expect(await repository.chargePowerWrites().isEmpty)
        viewModel.stop()
    }

    @Test("Charge power below observed minimum writes 300 watts")
    func chargePowerBelowObservedMinimumWrites300Watts() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargePowerDrag()
        viewModel.setDisplayedChargePower(watts: 100)
        viewModel.endChargePowerDrag()

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [300] })
        #expect(viewModel.viewState.chargePowerControl.selectedWatts == 300)
        viewModel.stop()
    }

    @Test("Charge target dragging does not write until release debounce")
    func chargeTargetDraggingDoesNotWriteUntilRelease() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargeTargetDrag()
        viewModel.setDisplayedChargeTarget(percent: 80)
        #expect(await repository.chargeTargetWrites().isEmpty)

        viewModel.endChargeTargetDrag()
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [80] })
        viewModel.stop()
    }

    @Test("Charge target rapid releases produce one final debounced write")
    func chargeTargetRapidReleasesProduceOneFinalWrite() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setDisplayedChargeTarget(percent: 90)
        viewModel.endChargeTargetDrag()
        viewModel.beginChargeTargetDrag()
        viewModel.setDisplayedChargeTarget(percent: 75)
        viewModel.endChargeTargetDrag()

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [75] })
        viewModel.stop()
    }

    @Test("Charge target confirmed value is not written again")
    func chargeTargetSameAsConfirmedSkipsWrite() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 80
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setDisplayedChargeTarget(percent: 80)
        viewModel.endChargeTargetDrag()

        try? await Task.sleep(for: .milliseconds(1_200))
        #expect(await repository.chargeTargetWrites().isEmpty)
        viewModel.stop()
    }

    @Test("Charge target clamps to 1 through 100 percent")
    func chargeTargetClampsToSupportedRange() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 80
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargeTargetDrag()
        viewModel.setDisplayedChargeTarget(percent: 0)
        viewModel.endChargeTargetDrag()
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [1] })

        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 1
        )
        viewModel.beginChargeTargetDrag()
        viewModel.setDisplayedChargeTarget(percent: 105)
        viewModel.endChargeTargetDrag()

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [1, 100] })
        viewModel.stop()
    }

    @Test("Charge target dragging ignores stale telemetry")
    func chargeTargetDraggingIgnoresStaleTelemetry() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargeTargetDrag()
        viewModel.setDisplayedChargeTarget(percent: 72)
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )

        #expect(await waitUntil {
            viewModel.viewState.chargePowerControl.selectedTargetPercent == 72
        })
        #expect(await repository.chargeTargetWrites().isEmpty)
        viewModel.stop()
    }

    @Test("Charge target waits for pending power confirmation")
    func chargeTargetWaitsForPendingPowerConfirmation() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.beginChargePowerDrag()
        viewModel.setDisplayedChargePower(watts: 1_500)
        viewModel.endChargePowerDrag()
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [1_500] })

        viewModel.beginChargeTargetDrag()
        viewModel.setDisplayedChargeTarget(percent: 80)
        viewModel.endChargeTargetDrag()
        try? await Task.sleep(for: .milliseconds(1_200))
        #expect(await repository.chargeTargetWrites().isEmpty)

        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_500,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [80] })
        viewModel.stop()
    }
}

private func sendChargingHealth(
    repository: FakeBatteryHealthRepository,
    maximumPowerWatts: Double,
    maximumStateOfChargePercent: Int = 100
) async {
    await repository.sendHealth(.init(
        chargeState: .charging,
        chargingStatus: .init(
            requestedCurrentAmperes: 2.5,
            reportedCurrentAmperes: 2.5,
            maximumCurrentAmperes: 20,
            maximumPowerWatts: maximumPowerWatts,
            targetCellVoltageVolts: 4.275,
            maximumStateOfChargePercent: maximumStateOfChargePercent,
            chargerType: .backpack
        )
    ))
}
