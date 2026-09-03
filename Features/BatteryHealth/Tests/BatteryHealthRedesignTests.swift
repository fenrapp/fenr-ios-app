@testable import BatteryHealth
import BikeDomain
import ChargeControl
import Foundation
import Testing
import TestSupport

@MainActor
@Suite("Battery Health redesign")
struct BatteryHealthRedesignTests {
    @Test("Destination family exposes every battery route")
    func destinationFamily() {
        #expect(BatteryHealthDestination.allCases == [
            .overview, .cells, .thermal, .charging, .rawData
        ])
    }

    @Test("Overall status includes collecting, healthy, attention, critical and unavailable")
    func overallStatus() {
        let mapper = makeBatteryHealthMapper(now: { Date(timeIntervalSince1970: 100) })

        #expect(mapper.map(
            health: .init(),
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).overview.status == .collecting)

        let healthy = BikeBatteryHealth(
            stateOfHealth: .known(percent: 95),
            cellVoltages: [
                .init(position: 1, volts: 3.90),
                .init(position: 2, volts: 3.91)
            ],
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        #expect(mapper.map(
            health: healthy,
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).overview.status == .healthy)
        #expect(mapper.map(
            health: healthy,
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).overview.stateOfHealthProgress == 0.95)

        var attention = healthy
        attention.cellVoltages = [
            .init(position: 1, volts: 3.88),
            .init(position: 2, volts: 3.92)
        ]
        #expect(mapper.map(
            health: attention,
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).overview.status == .attention)

        var critical = healthy
        critical.positiveBMSFaultBits = 1
        #expect(mapper.map(
            health: critical,
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).overview.status == .critical)

        #expect(mapper.map(
            health: healthy,
            captures: [:],
            isMonitoring: false,
            monitorError: "Unavailable"
        ).overview.status == .unavailable)
    }

    @Test("Partial battery datasets remain collecting instead of flashing a warning")
    func partialHealthStatus() {
        let mapper = makeBatteryHealthMapper(now: { Date(timeIntervalSince1970: 100) })
        let partial = BikeBatteryHealth(
            stateOfHealth: .known(percent: 75),
            lastUpdated: Date(timeIntervalSince1970: 100)
        )

        let overview = mapper.map(
            health: partial,
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).overview

        #expect(overview.status == .collecting)
        #expect(overview.statusDetail == "Waiting for confirmed battery datasets")
    }

    @Test("Cells expose extremes, millivolt delta and separate balancing")
    func cellDetail() {
        let mapper = makeBatteryHealthMapper()
        let state = mapper.map(
            health: .init(
                cellVoltages: [
                    .init(position: 1, volts: 3.80),
                    .init(position: 2, volts: 3.84),
                    .init(position: 3, volts: 3.90)
                ],
                balancingCellIndexes: [1]
            ),
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).cellsDetail

        #expect(state.metrics.contains { $0.id == "minimum" && $0.value.contains("#1") })
        #expect(state.metrics.contains { $0.id == "maximum" && $0.value.contains("#3") })
        #expect(state.metrics.contains(.init(id: "delta", title: "Delta", value: "100 mV")))
        #expect(state.distribution.criticalCount == 1)
        #expect(state.balancingCount == 1)
        #expect(state.cells[1].isBalancing)
        #expect(state.cells[0].deviationMillivolts < 0)
        #expect(state.cells[2].deviationMillivolts > 0)
    }

    @Test("Thermal detail exposes a neutral visual range without duplicating health thresholds")
    func thermalRange() {
        let mapper = makeBatteryHealthMapper()
        let state = mapper.map(
            health: .init(temperatures: [
                .init(position: 1, celsius: 24),
                .init(position: 2, celsius: 36)
            ]),
            captures: [:],
            isMonitoring: true,
            monitorError: nil
        ).thermalDetail

        #expect(state.valueRangeCelsius == 24 ... 36)
        #expect(state.averageCelsius == 30)
        #expect(state.displayDomainCelsius == 20 ... 40)
    }

    @Test("Partial health datasets merge without erasing confirmed values")
    func partialDatasetMerge() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.setPresentationActive(true)

        await repository.sendHealth(.init(
            stateOfCharge: .known(percent: 64),
            lastUpdated: Date()
        ))
        await repository.sendHealth(.init(
            cellVoltages: [
                .init(position: 1, volts: 3.80),
                .init(position: 2, volts: 3.82)
            ]
        ))

        #expect(await waitUntil {
            viewModel.viewState.overview.summaryMetrics.contains { $0.id == "soc" && $0.value == "64%" }
                && viewModel.viewState.cellsDetail.cells.count == 2
        })
        viewModel.setPresentationActive(false)
    }

    @Test("New confirmed samples clear balancing and fault state")
    func confirmedSamplesClearPriorState() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)
        viewModel.setPresentationActive(true)

        await repository.sendHealth(.init(
            positiveBMSFaultBits: 1,
            cellVoltages: [.init(position: 1, volts: 3.8)],
            balancingCellIndexes: [0],
            lastUpdated: Date()
        ))
        #expect(await waitUntil {
            viewModel.viewState.overview.status == .critical
                && viewModel.viewState.cellsDetail.balancingCount == 1
        })

        await repository.sendHealth(.init(
            cellVoltages: [.init(position: 1, volts: 3.9)],
            balancingCellIndexes: [],
            lastUpdated: Date()
        ))
        #expect(await waitUntil {
            viewModel.viewState.overview.status != .critical
                && viewModel.viewState.cellsDetail.balancingCount == 0
        })
        viewModel.setPresentationActive(false)
    }

    @Test("Changing bike clears cached datasets and raw captures")
    func vehicleIdentityReset() async {
        let repository = FakeBatteryHealthRepository()
        let session = FakeBatteryHealthVehicleSession(repository: repository)
        await session.setProfile(.init(vin: "FENRTEST000000001"))
        let viewModel = makeBatteryHealthViewModel(repository: repository, vehicleSession: session)
        viewModel.setPresentationActive(true)

        await repository.sendCapture(.init(
            dataset: .cellVoltages,
            byteCount: 4,
            hex: "AA BB CC DD",
            date: Date()
        ))
        await repository.sendHealth(.init(
            stateOfCharge: .known(percent: 70),
            cellVoltages: [.init(position: 1, volts: 3.8)]
        ))
        #expect(await waitUntil { viewModel.viewState.cellsDetail.cells.count == 1 })

        await session.setProfile(.init(vin: "FENRTEST000000002"))
        await repository.sendHealth(.init())

        #expect(await waitUntil {
            viewModel.viewState.cellsDetail.cells.isEmpty
                && viewModel.viewState.rawDataDetail.datasets.allSatisfy { $0.state == .awaiting }
        })
        viewModel.setPresentationActive(false)
    }

    @Test("Presentation restart reacquires monitoring after releasing the previous lease")
    func presentationLifecycleRestart() async {
        let repository = FakeBatteryHealthRepository()
        let viewModel = makeBatteryHealthViewModel(repository: repository)

        viewModel.setPresentationActive(true)
        viewModel.setPresentationActive(true)
        #expect(await waitUntil { await repository.monitoringStartCount() == 1 })

        viewModel.setPresentationActive(false)
        #expect(await waitUntil { await repository.monitoringStopCount() == 1 })

        viewModel.setPresentationActive(true)
        #expect(await waitUntil { await repository.monitoringStartCount() == 2 })

        viewModel.setPresentationActive(false)
        #expect(await waitUntil { await repository.monitoringStopCount() == 2 })
    }
}
