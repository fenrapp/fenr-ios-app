@testable import BatteryHealth
import BikeDomain
import ChargeControl
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
        #expect(await waitUntil {
            await repository.monitoringStarted() && viewModel.viewState.isMonitoring
        })

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
            viewModel.viewState.overview.summaryMetrics.contains(where: { $0.value == "76%" })
        })

        #expect(viewModel.viewState.overview.summaryMetrics.contains(.init(id: "soc", title: "SOC", value: "76%")))
        #expect(viewModel.viewState.overview.stateOfHealthMetric == .init(id: "soh", title: "SOH", value: "94%"))
        #expect(viewModel.viewState.overview.summaryMetrics.contains(
            .init(id: "charge", title: "Charge", value: "Charging")
        ))
        #expect(viewModel.viewState.overview.summaryMetrics.contains(
            .init(id: "dcBus", title: "DC bus", value: "394.8 V")
        ))
        viewModel.stop()
    }

    @Test("Stopping while BMS startup is pending releases monitoring in order")
    func stopDuringPendingMonitoringStart() async {
        let repository = FakeBatteryHealthRepository()
        await repository.delayNextMonitoringStart()
        let viewModel = makeBatteryHealthViewModel(repository: repository)

        viewModel.start()
        viewModel.stop()

        #expect(await waitUntil { await repository.monitoringStopped() })
        #expect(await repository.monitoringStarted())
        #expect(await repository.monitoringStopped())
        #expect(!viewModel.viewState.isMonitoring)
    }

    @Test("Pending monitoring release survives view model teardown")
    func pendingMonitoringReleaseSurvivesTeardown() async {
        let repository = FakeBatteryHealthRepository()
        await repository.delayNextMonitoringStart()
        var viewModel: BatteryHealthViewModel? = makeBatteryHealthViewModel(repository: repository)

        viewModel?.start()
        viewModel?.stop()
        viewModel = nil

        #expect(await waitUntil {
            let startCount = await repository.monitoringStartCount()
            let stopCount = await repository.monitoringStopCount()
            return startCount == 1 && stopCount == 1
        })
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
            viewModel.viewState.rawDataDetail.datasets.contains(where: {
                $0.status.emphasis == .warning
            })
        })

        #expect(viewModel.viewState.overview.summaryMetrics.contains(.init(id: "soc", title: "SOC", value: "--")))
        let cellsDataset = viewModel.viewState.rawDataDetail.datasets.first { $0.id == "cellVoltages" }
        #expect(cellsDataset?.title == "Cell voltages")
        #expect(cellsDataset?.status == .init(text: "Captured Only", emphasis: .warning))
        #expect(cellsDataset?.state == .capturedOnly)
        #expect(cellsDataset?.byteCount == 200)
        #expect(cellsDataset?.hex == "AA BB")
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
        #expect(await waitUntil { !viewModel.viewState.cellsDetail.cells.isEmpty })

        #expect(viewModel.viewState.cellsDetail.cells.count == 2)
        #expect(viewModel.viewState.cellsDetail.cells[0].isBalancing)
        #expect(viewModel.viewState.cellsDetail.cells[0].isMinimum)
        #expect(viewModel.viewState.cellsDetail.cells[1].isMaximum)
        #expect(viewModel.viewState.thermalDetail.sensors == [
            .init(position: 1, value: "82.6°F", emphasis: .positive)
        ])
        #expect(viewModel.viewState.rawDataDetail.datasets.contains(.init(
            id: "cellVoltages",
            title: "Cell voltages",
            status: .init(text: "Decoded", emphasis: .positive),
            state: .decoded
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
            ),
            lastUpdated: Date()
        ))
        #expect(await waitUntil { !viewModel.viewState.chargingDetail.metrics.isEmpty })

        #expect(viewModel.viewState.chargingDetail.metrics.contains(.init(
            id: "chargePowerLimit",
            title: "Power limit",
            value: "1 kW"
        )))
        #expect(viewModel.viewState.chargingDetail.metrics.contains(.init(
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
        #expect(await waitUntil { !viewModel.viewState.cellsDetail.cells.isEmpty })

        #expect(viewModel.viewState.cellsDetail.cells[0].condition == .aboveAverage)
        #expect(viewModel.viewState.cellsDetail.cells[2].condition == .critical)
        #expect(viewModel.viewState.cellsDetail.cells[2].deviation == "-53 mV")
        viewModel.stop()
    }

    @Test("Charge control semantic state maps to localized presentation text")
    func mapsChargeControlSemanticState() {
        let mapper = makeBatteryHealthMapper()
        let state = mapper.map(
            health: .init(),
            captures: [:],
            chargeControl: .init(
                isVisible: true,
                chargerType: .unknown(91),
                status: .confirming(.powerWatts(1_500)),
                failure: .confirmationTimedOut,
                phase: .failed
            ),
            isMonitoring: false,
            monitorError: nil
        ).chargingDetail.control

        #expect(state.chargerText == "Unknown charger (91)")
        #expect(state.statusText == "Confirming \(1_500.formatted()) W")
        #expect(state.errorText == "The bike did not confirm the change")
        #expect(state.statusIsError)
    }

    @Test("Monitoring failures do not expose transport details")
    func hidesMonitoringFailureDetails() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(
            repository: repository,
            monitoringState: .failed("transport detail")
        )
        viewModel.start()
        await repository.sendHealth(.init())

        #expect(await waitUntil {
            viewModel.viewState.monitorError == String(localized: .batteryHealthMonitoringError)
        })
        #expect(!(viewModel.viewState.monitorError ?? "").contains("transport detail"))
        viewModel.stop()
    }

}
