import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import VehicleSession

@Suite("System health card mapper")
struct SystemHealthCardMapperTests {
    private let mapper = RideDashboardMapperFactory.makeSystemHealthMapper(
        locale: Locale(identifier: "en_GB")
    )

    @Test("Maps healthy pack, cells, and thermal data")
    func mapsHealthyPack() {
        let state = mapper.map(snapshot(
            health: .init(
                stateOfHealth: .known(percent: 94),
                dcBusVoltage: .known(volts: 394.8),
                cellVoltages: [
                    .init(position: 1, volts: 3.890),
                    .init(position: 2, volts: 3.898)
                ],
                balancingCellIndexes: [0],
                temperatures: [
                    .init(position: 1, celsius: 24),
                    .init(position: 2, celsius: 28)
                ]
            ),
            inverterTemperatures: [39, 42, 44]
        ))

        #expect(state.status == .healthy)
        #expect(state.stateOfHealthText == "94%")
        #expect(state.cellDeltaText == "8 mV")
        #expect(state.dcBusVoltageText == "394.8 V")
        #expect(state.balancingCellCount == 1)
        #expect(state.cells.first?.isBalancing == true)
        #expect(state.batteryThermalRange?.averageText == "26°C")
        #expect(state.inverterThermalRange?.maximumText == "44°C")
    }

    @Test("Surfaces critical cells and BMS faults")
    func mapsCriticalPack() {
        var cells = (1 ... 99).map { BatteryCellVoltage(position: $0, volts: 3.9) }
        cells.append(.init(position: 100, volts: 2.85))
        let state = mapper.map(snapshot(health: .init(
            stateOfHealth: .known(percent: 94),
            positiveBMSFaultBits: 1,
            cellVoltages: cells
        )))

        #expect(state.status == .critical)
        #expect(state.statusDetail == "BMS FAULT ACTIVE")
        #expect(state.criticalCellCount == 1)
        #expect(state.cells.last?.condition == .critical)
    }

    @Test("Maps a uniformly depleted pack to low battery without cell failures")
    func mapsLowBatteryPack() {
        let cells = (1 ... 100).map { position in
            BatteryCellVoltage(position: position, volts: 2.95 + Double(position % 4) * 0.001)
        }
        let state = mapper.map(snapshot(health: .init(
            stateOfCharge: .known(percent: 2),
            stateOfHealth: .known(percent: 94),
            cellVoltages: cells,
            temperatures: [.init(position: 1, celsius: 25)]
        )))

        #expect(state.status == .lowBattery)
        #expect(state.statusText == "LOW BATTERY")
        #expect(state.statusDetail == "LOW BATTERY · CHARGE SOON")
        #expect(state.criticalCellCount == 0)
    }

    @Test("Does not label the generic vehicle fault flag as a BMS fault")
    func keepsGenericVehicleFaultSeparate() {
        let state = mapper.map(snapshot(health: .init(
            stateOfCharge: .known(percent: 80),
            stateOfHealth: .known(percent: 94),
            isFaultActive: true,
            cellVoltages: [.init(position: 1, volts: 3.9)]
        )))

        #expect(state.status == .healthy)
        #expect(state.statusDetail != "BMS FAULT ACTIVE")
    }

    @Test("Distinguishes scanning and unavailable monitoring")
    func mapsMonitoringStates() {
        let scanning = mapper.map(.init(batteryHealthMonitoringState: .starting))
        let unavailable = mapper.map(.init(batteryHealthMonitoringState: .failed("No BMS")))

        #expect(scanning.status == .scanning)
        #expect(scanning.statusDetail.isEmpty)
        #expect(scanning.stateOfHealthText == "N/A")
        #expect(scanning.stateOfHealthProgress == 0)
        #expect(unavailable.status == .unavailable)
        #expect(unavailable.statusDetail == "BMS DATA UNAVAILABLE")
    }

    @Test("Formats thermal values using the selected measurement system")
    func formatsImperialTemperatures() {
        let state = mapper.map(.init(
            telemetry: .init(inverterTemperaturesCelsius: [40]),
            settings: .init(measurementSystem: .imperial),
            batteryHealth: .init(
                stateOfHealth: .known(percent: 94),
                cellVoltages: [.init(position: 1, volts: 3.9)],
                temperatures: [.init(position: 1, celsius: 20)]
            ),
            batteryHealthMonitoringState: .active
        ))

        #expect(state.batteryTemperatureText == "68°F")
        #expect(state.inverterTemperatureText == "104°F")
    }

    private func snapshot(
        health: BikeBatteryHealth,
        inverterTemperatures: [Double?] = []
    ) -> VehicleSessionSnapshot {
        .init(
            telemetry: .init(inverterTemperaturesCelsius: inverterTemperatures),
            settings: .init(measurementSystem: .metric),
            batteryHealth: health,
            batteryHealthMonitoringState: .active
        )
    }
}
