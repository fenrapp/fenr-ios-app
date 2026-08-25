import BikeDomain
import Foundation

enum BikeEmulatorPayloadFactory {
    static func makeConnection() -> BikeConnection {
        BikeConnection(
            state: .receivingTelemetry(peripheralName: Constants.peripheralName),
            peripheralName: Constants.peripheralName,
            peripheralIdentifier: Constants.peripheralIdentifier,
            rssi: Constants.rssi
        )
    }

    static func makeTelemetry(
        scenario: BikeEmulatorScenario,
        powerModePreset: BikeEmulatorPowerModePreset,
        activeMapNumber: Int,
        tick: Int,
        date: Date
    ) -> BikeTelemetry {
        let isCharging = scenario == .charging
        let isRiding = scenario == .riding
        let batteryPercent = batteryPercent(for: scenario, tick: tick)
        let speed = isRiding ? ridingSpeed(for: tick) : .zero
        let indicators = indicatorState(for: scenario, tick: tick)
        return BikeTelemetry(
            vin: BikeEmulatorIdentity.vin,
            batteryLevel: .known(percent: batteryPercent),
            healthLevel: .known(percent: Constants.healthPercent),
            mode: .index(activeMapNumber),
            speed: .known(kmh: speed, kmhX10: Int(speed * Constants.speedScale)),
            motorRPM: .known(isRiding ? Int(speed * Constants.rpmPerKmh) : .zero),
            statusFlags: BikeStatusFlags(
                isOn: !isCharging,
                isCharging: isCharging,
                isChargerConnected: isCharging,
                isInGear: isRiding,
                isFaultActive: scenario == .cellAnomaly,
                isBrakeActive: isBrakeActive(for: scenario, tick: tick),
                indicatorState: indicators
            ),
            rawStatusFlags: BikeRawStatusFlags(
                alert: scenario == .cellAnomaly ? Constants.anomalyAlertFlag : .zero,
                fault: scenario == .cellAnomaly ? Constants.anomalyFaultFlag : .zero,
                info: isCharging ? Constants.chargingInfoFlag : Constants.ridingInfoFlag
            ),
            powerModeConfigurations: powerModeConfigurations(
                preset: powerModePreset,
                activeMapNumber: activeMapNumber
            ),
            detectedPowerTier: detectedPowerTier(preset: powerModePreset),
            lastUpdated: date
        )
    }

    static func makeBatteryHealth(
        scenario: BikeEmulatorScenario,
        tick: Int,
        date: Date,
        chargePowerLimitWatts: Int = 1_000,
        chargeTargetPercent: Int = 100
    ) -> BikeBatteryHealth {
        let isCharging = scenario == .charging
        return BikeBatteryHealth(
            stateOfCharge: .known(percent: batteryPercent(for: scenario, tick: tick)),
            stateOfHealth: .known(percent: Constants.healthPercent),
            dcBusVoltage: .known(volts: isCharging ? Constants.chargingBusVoltage : Constants.stationaryBusVoltage),
            chargeState: isCharging ? .charging : .disconnected,
            isFaultActive: scenario == .cellAnomaly,
            cellVoltages: makeCellVoltages(scenario: scenario, tick: tick),
            balancingCellIndexes: isCharging ? Constants.balancingCells : [],
            temperatures: makeTemperatures(tick: tick),
            chargingStatus: isCharging
                ? makeChargingStatus(
                    tick: tick,
                    chargePowerLimitWatts: chargePowerLimitWatts,
                    chargeTargetPercent: chargeTargetPercent
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

    private static func batteryPercent(for scenario: BikeEmulatorScenario, tick: Int) -> Int {
        switch scenario {
        case .charging:
            return Constants.chargingBatteryPercent + Int(
                (abs(sin(Double(tick) * Constants.chargingBatteryWaveRadians))
                    * Double(Constants.chargingBatteryAmplitude)).rounded()
            )
        case .riding:
            return max(
                Constants.ridingBatteryFloor,
                Constants.ridingBatteryPercent - tick / Constants.ridingBatteryDropInterval
            )
        case .cellAnomaly:
            return Constants.stationaryBatteryPercent
        }
    }

    private static func ridingSpeed(for tick: Int) -> Double {
        Constants.ridingSpeedMinimum + abs(sin(Double(tick) * Constants.ridingSpeedWaveRadians))
            * Constants.ridingSpeedAmplitude
    }

    private static func indicatorState(
        for scenario: BikeEmulatorScenario,
        tick: Int
    ) -> BikeIndicatorState {
        let isBlinking = tick.isMultiple(of: Constants.blinkIntervalTicks)
        switch scenario {
        case .riding:
            switch (tick / Constants.indicatorCycleTicks) % Constants.indicatorCycleCount {
            case .zero:
                return BikeIndicatorState(
                    isHighBeamOn: tick % Constants.highBeamCycleTicks < Constants.highBeamOnTicks,
                    isLeftBlinkerOn: isBlinking
                )
            case 1:
                return BikeIndicatorState(
                    isHighBeamOn: tick % Constants.highBeamCycleTicks < Constants.highBeamOnTicks,
                    isRightBlinkerOn: isBlinking
                )
            default:
                return BikeIndicatorState(
                    isHighBeamOn: tick % Constants.highBeamCycleTicks < Constants.highBeamOnTicks
                )
            }
        case .cellAnomaly:
            return BikeIndicatorState(
                isRightBlinkerOn: isBlinking,
                isLeftBlinkerOn: isBlinking,
                isCheckEngineLightOn: true
            )
        case .charging:
            return .init()
        }
    }

    private static func isBrakeActive(for scenario: BikeEmulatorScenario, tick: Int) -> Bool {
        scenario == .riding && tick % Constants.brakeCycleTicks >= Constants.brakeActiveStartTick
    }

    private static func makeChargingStatus(
        tick: Int,
        chargePowerLimitWatts: Int,
        chargeTargetPercent: Int
    ) -> BikeChargingStatus {
        let chargeLoad = abs(sin(Double(tick) * Constants.chargingLoadWaveRadians))
        let requestedCurrent = Constants.chargeCurrent + chargeLoad * Constants.chargingCurrentAmplitude
        let reportedCurrent = min(
            requestedCurrent,
            Double(chargePowerLimitWatts) / Constants.chargingBusVoltage
        )
        return BikeChargingStatus(
            requestedCurrentAmperes: requestedCurrent,
            reportedCurrentAmperes: reportedCurrent,
            maximumCurrentAmperes: Constants.maximumCurrent,
            maximumPowerWatts: Double(chargePowerLimitWatts),
            targetCellVoltageVolts: Constants.targetCellVoltage,
            maximumStateOfChargePercent: chargeTargetPercent,
            chargerType: .backpack
        )
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

}

private extension BikeEmulatorPayloadFactory {
    static func powerModeConfigurations(
        preset: BikeEmulatorPowerModePreset,
        activeMapNumber: Int
    ) -> [Int: BikePowerModeConfiguration] {
        switch preset {
        case .failure:
            return [:]
        case .partial:
            let configurationIndex = activeMapNumber - 1
            return [configurationIndex: .init(mapIndex: configurationIndex, powerTractionPercent: 20)]
        case .standard, .claimedAlpha:
            let horsepower = [20, 30, 40, 50, 60]
            let regenerativeBraking = [10.0, 20, 30, 40, 50]
            return Dictionary(uniqueKeysWithValues: horsepower.enumerated().map {
                ($0.offset, BikePowerModeConfiguration(
                    mapIndex: $0.offset,
                    horsepower: $0.element,
                    regenerativeBrakingPercent: regenerativeBraking[$0.offset]
                ))
            })
        case .alpha, .mismatch:
            let horsepower = [20, 35, 50, 65, 80]
            let regenerativeBraking = [10.0, 20, 30, 40, 50]
            let powerTraction = [0.0, 10, 20, 30, 40]
            let brakingTraction = [0.0, 5, 10, 15, 20]
            return Dictionary(uniqueKeysWithValues: horsepower.indices.map {
                ($0, BikePowerModeConfiguration(
                    mapIndex: $0,
                    horsepower: horsepower[$0],
                    regenerativeBrakingPercent: regenerativeBraking[$0],
                    powerTractionPercent: powerTraction[$0],
                    brakingTractionPercent: brakingTraction[$0]
                ))
            })
        }
    }

    static func detectedPowerTier(preset: BikeEmulatorPowerModePreset) -> BikeDetectedPowerTier {
        switch preset {
        case .alpha, .mismatch:
            .alpha(evidence: [.powerAboveStandard, .tractionControlConfigured])
        case .standard, .claimedAlpha, .partial, .failure:
            .standardBaseline
        }
    }
}

private extension BikeEmulatorPayloadFactory {
    enum Constants {
        static let peripheralName = BikeEmulatorIdentity.vin
        static let peripheralIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        static let rssi = -48
        static let stationaryBatteryPercent = 68
        static let chargingBatteryPercent = 68
        static let chargingBatteryAmplitude = 26
        static let chargingBatteryWaveRadians = 0.06
        static let ridingBatteryPercent = 72
        static let ridingBatteryFloor = 50
        static let ridingBatteryDropInterval = 20
        static let healthPercent = 94
        static let ridingSpeedMinimum = 18.0
        static let ridingSpeedAmplitude = 132.0
        static let ridingSpeedWaveRadians = 0.13
        static let blinkIntervalTicks = 2
        static let indicatorCycleTicks = 6
        static let indicatorCycleCount = 3
        static let highBeamCycleTicks = 8
        static let highBeamOnTicks = 4
        static let brakeCycleTicks = 6
        static let brakeActiveStartTick = 4
        static let speedScale = 10.0
        static let rpmPerKmh = 75.0
        static let anomalyAlertFlag = 1
        static let anomalyFaultFlag = 1
        static let chargingInfoFlag = 0x0414
        static let ridingInfoFlag = 0x0212
        static let chargingBusVoltage = 388.4
        static let stationaryBusVoltage = 387.4
        static let chargeCurrent = 2.5
        static let chargingCurrentAmplitude = 12.0
        static let chargingLoadWaveRadians = 0.14
        static let maximumCurrent = 20.0
        static let targetCellVoltage = 4.275
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
