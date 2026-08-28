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
        tick: Int,
        context: BikeEmulatorTelemetryContext,
        powerCalculator: BikePowerTelemetryCalculator
    ) -> BikeTelemetry {
        let batteryPercent = batteryPercent(for: scenario, tick: tick)
        let isCharging = shouldSupplyChargeCurrent(
            scenario: scenario,
            batteryPercent: batteryPercent,
            chargeTargetPercent: context.chargeTargetPercent
        )
        let isRiding = scenario.isRiding
        let speed = isRiding ? ridingSpeed(for: tick) : .zero
        let ridingGear = ridingGearState(for: tick, fallbackMapNumber: context.activeMapNumber)
        let indicators = indicatorState(for: scenario, tick: tick)
        let electricalTelemetry = BikeEmulatorElectricalTelemetryFactory.make(
            context: .init(
                batteryPercent: batteryPercent,
                isCharging: isCharging,
                isRiding: isRiding,
                tick: tick,
                date: context.date
            ),
            powerCalculator: powerCalculator
        )
        return BikeTelemetry(
            vin: BikeEmulatorIdentity.vin,
            batteryLevel: .known(percent: batteryPercent),
            healthLevel: .known(percent: Constants.healthPercent),
            mode: .index(isRiding ? ridingGear.mapNumber : context.activeMapNumber),
            speed: .known(kmh: speed, kmhX10: Int(speed * Constants.speedScale)),
            motorRPM: .known(isRiding ? Int(speed * Constants.rpmPerKmh) : .zero),
            odometer: odometer(for: scenario, tick: tick),
            inverterTemperaturesCelsius: inverterTemperatures(for: tick),
            statusFlags: BikeStatusFlags(
                isOn: !scenario.isChargerConnected,
                isCharging: isCharging,
                isChargerConnected: scenario.isChargerConnected,
                isInGear: isRiding && ridingGear.isInGear,
                isFaultActive: scenario == .cellAnomaly,
                isBrakeActive: isBrakeActive(for: scenario, tick: tick),
                crawlState: isRiding ? ridingGear.crawlState : .inactive,
                indicatorState: indicators
            ),
            rawStatusFlags: BikeRawStatusFlags(
                alert: scenario == .cellAnomaly ? Constants.anomalyAlertFlag : .zero,
                fault: scenario == .cellAnomaly ? Constants.anomalyFaultFlag : .zero,
                info: isCharging ? Constants.chargingInfoFlag : Constants.ridingInfoFlag
            ),
            powerModeConfigurations: BikeEmulatorPowerModeTelemetryFactory.configurations(
                preset: context.powerModePreset,
                activeMapNumber: context.activeMapNumber
            ),
            detectedPowerTier: BikeEmulatorPowerModeTelemetryFactory.detectedTier(
                preset: context.powerModePreset
            ),
            powerTelemetry: electricalTelemetry.power,
            batteryTelemetry: electricalTelemetry.battery,
            lastUpdated: context.date
        )
    }

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
            isFaultActive: scenario == .cellAnomaly,
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

    private static func batteryPercent(for scenario: BikeEmulatorScenario, tick: Int) -> Int {
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
        case .cellAnomaly:
            return Constants.stationaryBatteryPercent
        }
    }

    private static func ridingBatteryPercent(for tick: Int) -> Int {
        let cycleLength = Constants.ridingBatteryPeakPercent * 2
        let cycleTick = tick % cycleLength
        let distanceFromPeak = min(cycleTick, cycleLength - cycleTick)
        return Constants.ridingBatteryPeakPercent - distanceFromPeak
    }

    private static func ridingSpeed(for tick: Int) -> Double {
        let ascentTickCount = Int(Constants.ridingSpeedMaximum / Constants.ridingSpeedStep)
        let cycleTick = tick % (ascentTickCount * 2)
        let distanceFromZero = min(cycleTick, (ascentTickCount * 2) - cycleTick)
        return Double(distanceFromZero) * Constants.ridingSpeedStep
    }

    private static func odometer(for scenario: BikeEmulatorScenario, tick: Int) -> BikeOdometer {
        let kilometers = Constants.odometerKilometers
            + (scenario.isRiding ? Double(tick) * Constants.ridingOdometerStepKilometers : .zero)
        return .known(
            kilometers: kilometers,
            centiKilometers: UInt32((kilometers * 100).rounded())
        )
    }

    private static func ridingGearState(
        for tick: Int,
        fallbackMapNumber: Int
    ) -> RidingGearState {
        let cycleStep = (tick / Constants.gearStateDurationTicks) % Constants.gearStateCount
        return switch cycleStep {
        case .zero:
            .init(mapNumber: fallbackMapNumber, isInGear: false, crawlState: .inactive)
        case 1:
            .init(mapNumber: fallbackMapNumber, isInGear: false, crawlState: .forward)
        case 2:
            .init(mapNumber: fallbackMapNumber, isInGear: false, crawlState: .reverse)
        default:
            .init(
                mapNumber: cycleStep - Constants.nonNumericGearStateOffset,
                isInGear: true,
                crawlState: .inactive
            )
        }
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

    private static func inverterTemperatures(for tick: Int) -> [Double?] {
        let thermalOffset = sin(Double(tick) * Constants.inverterTemperatureWaveRadians)
            * Constants.inverterTemperatureWaveAmplitude
        let base = Constants.inverterBaseTemperature + thermalOffset
        return [base, base + 2.5, base + 1.2]
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

private struct RidingGearState {
    let mapNumber: Int
    let isInGear: Bool
    let crawlState: BikeCrawlState
}

private extension BikeEmulatorPayloadFactory {
    static func indicatorState(
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
        case .ridingClean:
            return .init()
        case .cellAnomaly:
            return BikeIndicatorState(
                isRightBlinkerOn: isBlinking,
                isLeftBlinkerOn: isBlinking,
                isCheckEngineLightOn: true
            )
        case .charging, .cellBalancing, .chargerIdle, .chargingDataUnavailable:
            return .init()
        }
    }

    static func isBrakeActive(for scenario: BikeEmulatorScenario, tick: Int) -> Bool {
        scenario == .riding && tick % Constants.brakeCycleTicks >= Constants.brakeActiveStartTick
    }

    static func shouldSupplyChargeCurrent(
        scenario: BikeEmulatorScenario,
        batteryPercent: Int,
        chargeTargetPercent: Int
    ) -> Bool {
        scenario == .cellBalancing
            || (scenario.isCharging && batteryPercent < chargeTargetPercent)
    }

}

private extension BikeEmulatorPayloadFactory {
    enum Constants {
        static let peripheralName = BikeEmulatorIdentity.vin
        static let peripheralIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        static let rssi = -48
        static let stationaryBatteryPercent = 68
        static let fullBatteryPercent = 100
        static let chargingBatteryPercent = 68
        static let chargingBatteryAmplitude = 26
        static let chargingBatteryWaveRadians = 0.06
        static let ridingBatteryPeakPercent = 72
        static let healthPercent = 94
        static let ridingSpeedMaximum = 180.0
        static let ridingSpeedStep = 5.0
        static let gearStateDurationTicks = 4
        static let gearStateCount = 8
        static let nonNumericGearStateOffset = 2
        static let blinkIntervalTicks = 2
        static let indicatorCycleTicks = 6
        static let indicatorCycleCount = 3
        static let highBeamCycleTicks = 8
        static let highBeamOnTicks = 4
        static let brakeCycleTicks = 6
        static let brakeActiveStartTick = 4
        static let speedScale = 10.0
        static let rpmPerKmh = 75.0
        static let odometerKilometers = 1_842.7
        static let ridingOdometerStepKilometers = 0.05
        static let anomalyAlertFlag = 1
        static let anomalyFaultFlag = 1
        static let chargingInfoFlag = 0x0414
        static let ridingInfoFlag = 0x0212
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
        static let inverterBaseTemperature = 39.0
        static let inverterTemperatureWaveAmplitude = 4.0
        static let inverterTemperatureWaveRadians = 0.09
        static let bmsStatusByteCount = 16
        static let temperaturesByteCount = 27
        static let dcBusByteCount = 6
        static let cellVoltagesByteCount = 200
        static let balancingByteCount = 13
        static let signalsByteCount = 18
        static let chargerByteCount = 19
    }
}
