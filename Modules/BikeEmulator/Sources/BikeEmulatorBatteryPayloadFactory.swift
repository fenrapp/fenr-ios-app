import BikeDomain
import Foundation

enum BikeEmulatorBatteryPayloadFactory {
    static func makeBatteryHealth(
        scenario: BikeEmulatorScenario,
        tick: Int,
        date: Date,
        chargePowerLimitWatts: Int = 1_000,
        chargeTargetPercent: Int = 100
    ) -> BikeBatteryHealth {
        if scenario == .chargingDataUnavailable {
            return BikeBatteryHealth(lastUpdated: date)
        }

        let batteryPercent = batteryPercent(for: scenario, tick: tick)
        let isCharging = shouldSupplyChargeCurrent(
            scenario: scenario,
            batteryPercent: batteryPercent,
            chargeTargetPercent: chargeTargetPercent
        )
        let isChargerConnected = scenario.isChargerConnected
        return BikeBatteryHealth(
            stateOfCharge: .known(percent: batteryPercent),
            stateOfHealth: .known(percent: Constants.healthPercent),
            dcBusVoltage: .known(
                volts: isChargerConnected ? Constants.chargingBusVoltage : Constants.stationaryBusVoltage
            ),
            chargeState: isCharging ? .charging : (isChargerConnected ? .connected : .disconnected),
            isVehicleFaultActive: scenario == .cellAnomaly,
            cellVoltages: makeCellVoltages(scenario: scenario, tick: tick),
            balancingCellIndexes: scenario == .cellBalancing ? Constants.balancingCells : [],
            temperatures: makeTemperatures(tick: tick),
            chargingStatus: isChargerConnected
                ? BikeEmulatorChargingStatusFactory.make(
                    tick: tick,
                    chargePowerLimitWatts: chargePowerLimitWatts,
                    chargeTargetPercent: chargeTargetPercent,
                    isCharging: isCharging,
                    chargingBusVoltage: Constants.chargingBusVoltage
                )
                : nil,
            lastUpdated: date
        )
    }

    static func makeCaptures(
        scenario: BikeEmulatorScenario,
        tick: Int,
        date: Date
    ) -> [BatteryDatasetCapture] {
        BatteryDataset.allCases.map { dataset in
            BatteryDatasetCapture(
                dataset: dataset,
                byteCount: byteCount(for: dataset),
                hex: "Debug \(scenario.rawValue) frame \(tick)",
                date: date
            )
        }
    }

    static func batteryPercent(for scenario: BikeEmulatorScenario, tick: Int) -> Int {
        switch scenario {
        case .charging:
            return Constants.chargingBatteryPercent + Int(
                (abs(sin(Double(tick) * Constants.chargingBatteryWaveRadians))
                    * Double(Constants.chargingBatteryAmplitude)).rounded()
            )
        case .cellBalancing:
            return Constants.fullBatteryPercent
        case .chargerIdle, .chargingDataUnavailable:
            return Constants.stationaryBatteryPercent
        case .riding, .ridingClean:
            return ridingBatteryPercent(for: tick)
        case .parked, .cellAnomaly:
            return Constants.stationaryBatteryPercent
        }
    }

    static func shouldSupplyChargeCurrent(
        scenario: BikeEmulatorScenario,
        batteryPercent: Int,
        chargeTargetPercent: Int
    ) -> Bool {
        scenario == .cellBalancing
            || (scenario.isCharging && batteryPercent < chargeTargetPercent)
    }

    private static func ridingBatteryPercent(for tick: Int) -> Int {
        let cycleLength = Constants.ridingBatteryPeakPercent * 2
        let cycleTick = tick % cycleLength
        let distanceFromPeak = min(cycleTick, cycleLength - cycleTick)
        return Constants.ridingBatteryPeakPercent - distanceFromPeak
    }

    private static func makeCellVoltages(
        scenario: BikeEmulatorScenario,
        tick: Int
    ) -> [BatteryCellVoltage] {
        (Constants.firstCellPosition ... Constants.cellCount).map { position in
            let variation = Double(
                (position * Constants.cellVariationMultiplier + tick) % Constants.cellVariationRange
            )
            let volts = Constants.nominalCellVoltage + variation * Constants.cellVariationStep
            return BatteryCellVoltage(
                position: position,
                volts: anomalousVoltage(for: position, scenario: scenario, fallback: volts)
            )
        }
    }

    private static func anomalousVoltage(
        for position: Int,
        scenario: BikeEmulatorScenario,
        fallback: Double
    ) -> Double {
        guard scenario == .cellAnomaly else { return fallback }
        return switch position {
        case Constants.criticalCellPosition: Constants.criticalCellVoltage
        case Constants.lowCellPosition: Constants.lowCellVoltage
        case Constants.highCellPosition: Constants.highCellVoltage
        default: fallback
        }
    }

    private static func makeTemperatures(tick: Int) -> [BatteryTemperature] {
        let thermalOffset = sin(Double(tick) * Constants.temperatureWaveRadians)
            * Constants.temperatureWaveAmplitude
        return (Constants.firstTemperaturePosition ... Constants.temperatureCount).map { position in
            let variation = Double((position + tick) % Constants.temperatureVariationRange)
            return BatteryTemperature(
                position: position,
                celsius: Constants.baseTemperature + thermalOffset + variation * Constants.temperatureVariationStep
            )
        }
    }

    private static func byteCount(for dataset: BatteryDataset) -> Int {
        switch dataset {
        case .bmsStatus: Constants.bmsStatusByteCount
        case .temperatures: Constants.temperaturesByteCount
        case .dcBus: Constants.dcBusByteCount
        case .cellVoltages: Constants.cellVoltagesByteCount
        case .balancing: Constants.balancingByteCount
        case .signals: Constants.signalsByteCount
        case .charger: Constants.chargerByteCount
        }
    }

    private enum Constants {
        static let stationaryBatteryPercent = 68
        static let fullBatteryPercent = 100
        static let chargingBatteryPercent = 68
        static let chargingBatteryAmplitude = 26
        static let chargingBatteryWaveRadians = 0.06
        static let ridingBatteryPeakPercent = 72
        static let healthPercent = 94
        static let chargingBusVoltage = 388.4
        static let stationaryBusVoltage = 387.4
        static let balancingCells: Set<Int> = [12, 57]
        static let firstCellPosition = 1
        static let cellCount = 100
        static let nominalCellVoltage = 3.89
        static let cellVariationMultiplier = 7
        static let cellVariationRange = 9
        static let cellVariationStep = 0.001
        static let criticalCellPosition = 18
        static let criticalCellVoltage = 2.85
        static let lowCellPosition = 37
        static let lowCellVoltage = 3.84
        static let highCellPosition = 73
        static let highCellVoltage = 3.96
        static let firstTemperaturePosition = 1
        static let temperatureCount = 12
        static let baseTemperature = 22.0
        static let temperatureWaveAmplitude = 3.0
        static let temperatureWaveRadians = 0.11
        static let temperatureVariationRange = 5
        static let temperatureVariationStep = 0.7
        static let bmsStatusByteCount = 16
        static let temperaturesByteCount = 27
        static let dcBusByteCount = 6
        static let cellVoltagesByteCount = 200
        static let balancingByteCount = 13
        static let signalsByteCount = 18
        static let chargerByteCount = 19
    }
}
