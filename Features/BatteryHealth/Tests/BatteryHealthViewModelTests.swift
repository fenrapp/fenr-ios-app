@testable import BatteryHealth
import BikeDomain
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Battery Health view model")
struct BatteryHealthViewModelTests {
    @Test("Monitoring starts only when the screen starts")
    func startMonitoring() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)

        #expect(!(await repository.monitoringStarted()))

        viewModel.start()
        #expect(await waitUntil { await repository.monitoringStarted() })

        #expect(await repository.monitoringStarted())
        #expect(viewModel.viewState.isMonitoring)
        viewModel.stop()
        #expect(await waitUntil { await repository.monitoringStopped() })
        #expect(await repository.monitoringStopped())
    }

    @Test("Confirmed SOC payload maps to the health summary")
    func mapsHealthSummary() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await repository.sendHealth(.init(
            stateOfCharge: .known(percent: 76),
            stateOfHealth: .known(percent: 94),
            dcBusVoltage: .known(volts: 394.8),
            chargeState: .charging,
            lastUpdated: Date(timeIntervalSince1970: 0)
        ))
        #expect(await waitUntil {
            viewModel.viewState.summary.contains(where: { $0.value == "76%" })
        })

        #expect(viewModel.viewState.summary.contains(.init(id: "soc", title: "SOC", value: "76%")))
        #expect(viewModel.viewState.summary.contains(.init(id: "soh", title: "SOH", value: "94%")))
        #expect(viewModel.viewState.summary.contains(.init(id: "charge", title: "Charge", value: "Charging")))
        #expect(viewModel.viewState.summary.contains(.init(id: "dcBus", title: "DC bus", value: "394.8 V")))
        viewModel.stop()
    }

    @Test("Unknown data remains a placeholder and captures never become numeric health values")
    func captureStatus() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await repository.sendCapture(.init(
            dataset: .cellVoltages,
            byteCount: 200,
            hex: "AA BB",
            date: Date(timeIntervalSince1970: 0)
        ))
        #expect(await waitUntil {
            viewModel.viewState.datasets.contains(where: {
                $0.status.emphasis == .warning
            })
        })

        #expect(viewModel.viewState.summary.contains(.init(id: "soc", title: "SOC", value: "--")))
        #expect(viewModel.viewState.datasets.contains(.init(
            id: "cellVoltages",
            title: "Cell voltages",
            status: .init(text: "Captured 200 B", emphasis: .warning)
        )))
        #expect(viewModel.captureLogText().contains("AA BB"))
        viewModel.stop()
    }

    @Test("Decoded cells and temperatures become validated health data")
    func mapsValidatedPackData() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await repository.sendHealth(.init(
            cellVoltages: [
                .init(position: 1, volts: 3.8286),
                .init(position: 2, volts: 3.8476)
            ],
            balancingCellIndexes: [0],
            temperatures: [.init(position: 1, celsius: 28.1)]
        ))
        #expect(await waitUntil { !viewModel.viewState.cells.isEmpty })

        #expect(viewModel.viewState.cells.count == 2)
        #expect(viewModel.viewState.cells[0].isBalancing)
        #expect(viewModel.viewState.cells[0].isMinimum)
        #expect(viewModel.viewState.cells[1].isMaximum)
        #expect(viewModel.viewState.temperatures == [.init(position: 1, value: "82.6°F")])
        #expect(viewModel.viewState.datasets.contains(.init(
            id: "cellVoltages",
            title: "Cell voltages",
            status: .init(text: "Validated", emphasis: .positive)
        )))
        viewModel.stop()
    }

    @Test("Charging metrics are exposed only during an active charge session")
    func mapsChargingMetrics() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await repository.sendHealth(.init(
            dcBusVoltage: .known(volts: 390),
            chargeState: .charging,
            chargingStatus: .init(
                requestedCurrentAmperes: 2.5,
                reportedCurrentAmperes: 2.5,
                maximumCurrentAmperes: 20,
                maximumPowerWatts: 1_000,
                targetCellVoltageVolts: 4.275,
                maximumStateOfChargePercent: 100
            )
        ))
        #expect(await waitUntil { !viewModel.viewState.charging.isEmpty })

        #expect(viewModel.viewState.charging.contains(.init(
            id: "chargePowerLimit",
            title: "Power limit",
            value: "1 kW"
        )))
        #expect(viewModel.viewState.charging.contains(.init(
            id: "chargeCellTarget",
            title: "Cell target",
            value: "4.2750 V"
        )))
        viewModel.stop()
    }

    @Test("Cell conditions make harmful voltage deviations visible")
    func mapsCellConditions() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.start()
        await repository.sendHealth(.init(
            cellVoltages: [
                .init(position: 1, volts: 3.9),
                .init(position: 2, volts: 3.9),
                .init(position: 3, volts: 3.82)
            ]
        ))
        #expect(await waitUntil { !viewModel.viewState.cells.isEmpty })

        #expect(viewModel.viewState.cells[0].condition == .aboveAverage)
        #expect(viewModel.viewState.cells[2].condition == .critical)
        #expect(viewModel.viewState.cells[2].deviation == "-53 mV")
        viewModel.stop()
    }

}
