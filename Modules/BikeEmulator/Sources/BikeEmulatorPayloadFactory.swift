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
        let batteryPercent = BikeEmulatorBatteryPayloadFactory.batteryPercent(
            for: scenario,
            tick: tick
        )
        let isCharging = BikeEmulatorBatteryPayloadFactory.shouldSupplyChargeCurrent(
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

    private static func inverterTemperatures(for tick: Int) -> [Double?] {
        let thermalOffset = sin(Double(tick) * Constants.inverterTemperatureWaveRadians)
            * Constants.inverterTemperatureWaveAmplitude
        let base = Constants.inverterBaseTemperature + thermalOffset
        return [base, base + 2.5, base + 1.2]
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

}

private extension BikeEmulatorPayloadFactory {
    enum Constants {
        static let peripheralName = BikeEmulatorIdentity.vin
        static let peripheralIdentifier = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        static let rssi = -48
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
        static let inverterBaseTemperature = 39.0
        static let inverterTemperatureWaveAmplitude = 4.0
        static let inverterTemperatureWaveRadians = 0.09
    }
}
