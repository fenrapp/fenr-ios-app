@testable import BatteryHealth
import BikeDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Battery Health charge control view model")
struct BatteryHealthChargeControlViewModelTests {
    @Test("Charge power request waits for debounce")
    func chargePowerRequestWaitsForDebounce() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargePowerLimit(watts: 2_500)
        #expect(await repository.chargePowerWrites().isEmpty)

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [2_500] })
        viewModel.stop()
    }

    @Test("Charge controls disable while a power update is pending")
    func chargeControlsDisableDuringPowerUpdate() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargePowerLimit(watts: 2_000)
        viewModel.setChargePowerLimit(watts: 2_700)

        #expect(await waitUntil {
            !viewModel.viewState.chargingDetail.control.isEnabled
                && viewModel.viewState.chargingDetail.control.power.selected == 2_000
        })
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [2_000] })
        viewModel.stop()
    }

    @Test("Charge power request keeps optimistic value while old telemetry arrives")
    func chargePowerRequestKeepsOptimisticValue() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargePowerLimit(watts: 1_500)
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)

        #expect(await waitUntil {
            viewModel.viewState.chargingDetail.control.power.selected == 1_500
        })
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [1_500] })
        viewModel.stop()
    }

    @Test("Charge power request ignores stale telemetry during debounce")
    func chargePowerRequestIgnoresStaleTelemetryDuringDebounce() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargePowerLimit(watts: 2_200)
        await sendChargingHealth(repository: repository, maximumPowerWatts: 1_000)

        #expect(await waitUntil {
            viewModel.viewState.chargingDetail.control.power.selected == 2_200
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

        viewModel.setChargePowerLimit(watts: 1_000)

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

        viewModel.setChargePowerLimit(watts: 100)

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [300] })
        #expect(viewModel.viewState.chargingDetail.control.power.selected == 300)
        viewModel.stop()
    }

    @Test("Charge target request waits for debounce")
    func chargeTargetRequestWaitsForDebounce() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargeTarget(percent: 80)
        #expect(await repository.chargeTargetWrites().isEmpty)

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [80] })
        viewModel.stop()
    }

    @Test("Charge controls disable while a target update is pending")
    func chargeControlsDisableDuringTargetUpdate() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargeTarget(percent: 90)
        viewModel.setChargeTarget(percent: 75)

        #expect(await waitUntil {
            !viewModel.viewState.chargingDetail.control.isEnabled
                && viewModel.viewState.chargingDetail.control.target.selected == 90
        })
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [90] })
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

        viewModel.setChargeTarget(percent: 80)

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

        viewModel.setChargeTarget(percent: 0)
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [1] })

        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 1
        )
        #expect(await waitUntil { viewModel.viewState.chargingDetail.control.isEnabled })
        viewModel.setChargeTarget(percent: 105)

        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargeTargetWrites() == [1, 100] })
        viewModel.stop()
    }

    @Test("Charge target request ignores stale telemetry during debounce")
    func chargeTargetRequestIgnoresStaleTelemetryDuringDebounce() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargeTarget(percent: 72)
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )

        #expect(await waitUntil {
            viewModel.viewState.chargingDetail.control.target.selected == 72
        })
        #expect(await repository.chargeTargetWrites().isEmpty)
        viewModel.stop()
    }

    @Test("Pending power confirmation disables target changes")
    func pendingPowerConfirmationDisablesTargetChanges() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_000,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { await repository.chargePowerPrepareCount() == 1 })

        viewModel.setChargePowerLimit(watts: 1_500)
        #expect(await waitUntil(timeout: .seconds(2)) { await repository.chargePowerWrites() == [1_500] })

        viewModel.setChargeTarget(percent: 80)
        try? await Task.sleep(for: .milliseconds(1_200))
        #expect(await repository.chargeTargetWrites().isEmpty)
        #expect(!viewModel.viewState.chargingDetail.control.isEnabled)

        await sendChargingHealth(
            repository: repository,
            maximumPowerWatts: 1_500,
            maximumStateOfChargePercent: 100
        )
        #expect(await waitUntil { viewModel.viewState.chargingDetail.control.isEnabled })
        #expect(await repository.chargeTargetWrites().isEmpty)
        viewModel.setChargeTarget(percent: 80)
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
        ),
        lastUpdated: Date()
    ))
}
