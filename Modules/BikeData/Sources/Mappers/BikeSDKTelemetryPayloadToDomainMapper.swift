import BikeDomain
import BikeSDK
import Foundation
import StarkProtocol

public struct BikeSDKTelemetryPayloadToDomainMapper: Sendable {
    private let powerCalculator: BikePowerTelemetryCalculator

    public init(powerCalculator: BikePowerTelemetryCalculator) {
        self.powerCalculator = powerCalculator
    }

    @discardableResult
    public func apply(_ payload: BikeSDKTelemetryPayload, to telemetry: inout BikeTelemetry, date: Date) -> Bool {
        switch payload {
        case .status(let status):
            apply(status, to: &telemetry)
        case .vcuBrake(let brake):
            telemetry.statusFlags = BikeStatusFlags(
                isOn: telemetry.statusFlags.isOn,
                isCharging: telemetry.statusFlags.isCharging,
                isChargerConnected: telemetry.statusFlags.isChargerConnected,
                isInGear: telemetry.statusFlags.isInGear,
                isFaultActive: telemetry.statusFlags.isFaultActive,
                isBrakeActive: brake.isBrakeActive,
                crawlState: telemetry.statusFlags.crawlState,
                indicatorState: telemetry.statusFlags.indicatorState
            )
        case .map(let map):
            telemetry.mode = .index(map)
        case .powerModeConfiguration(let configuration):
            apply(configuration, to: &telemetry)
        case .tractionControlConfiguration(let configuration):
            apply(configuration, to: &telemetry)
        case .speed(let speed):
            apply(speed, to: &telemetry)
        case .liveTotals(let totals):
            apply(totals, to: &telemetry)
        case .inverterTemperatures(let temperatures):
            telemetry.inverterTemperatureRawValues = temperatures.rawValues
            telemetry.inverterTemperaturesCelsius = temperatures.celsius
        case .vin(let vin):
            telemetry.vin = vin
        case .battery(let battery):
            apply(battery, to: &telemetry, date: date)
        case .batterySignals(let signals):
            apply(signals, to: &telemetry, date: date)
        case .batteryParameters, .liveEstimations,
             .cellVoltages, .batteryTemperatures, .batteryBalancing, .charger, .throttle, .imu:
            return false
        }
        telemetry.lastUpdated = date
        return true
    }

    private func apply(_ status: StarkStatusPayload, to telemetry: inout BikeTelemetry) {
        telemetry.statusFlags = BikeStatusFlags(
            isOn: status.isOn,
            isCharging: status.isCharging,
            isChargerConnected: status.isChargerConnected,
            isInGear: status.isInGear,
            isFaultActive: status.isFaultActive,
            isBrakeActive: telemetry.statusFlags.isBrakeActive,
            crawlState: crawlState(isActive: status.isCrawlActive, isForward: status.isCrawlForward),
            indicatorState: .init(
                isHighBeamOn: status.isHighBeamOn,
                isRightBlinkerOn: status.isRightBlinkerOn,
                isLeftBlinkerOn: status.isLeftBlinkerOn,
                isCheckEngineLightOn: status.isCheckEngineLightOn
            )
        )
        telemetry.rawStatusFlags = BikeRawStatusFlags(
            misc: Int(status.miscBits),
            indicator: Int(status.indicatorBits),
            alert: Int(status.alertBits),
            fault: Int(status.faultBits),
            info: Int(status.infoBits)
        )
    }

    private func apply(
        _ battery: StarkBatteryPayload,
        to telemetry: inout BikeTelemetry,
        date: Date
    ) {
        telemetry.batteryTelemetry.stateOfCharge = .known(percent: battery.stateOfChargePercent)
        telemetry.batteryTelemetry.stateOfHealth = healthLevel(percent: battery.stateOfHealthPercent)
        telemetry.batteryTelemetry.dcBusRaw = battery.dcBusRaw
        telemetry.batteryTelemetry.dcBusVolts = battery.dcBusVolts
        telemetry.batteryTelemetry.stateUpdatedAt = date
        recalculatePower(in: &telemetry, date: date)
    }

    private func apply(
        _ signals: StarkBatterySignalsPayload,
        to telemetry: inout BikeTelemetry,
        date: Date
    ) {
        telemetry.batteryTelemetry.currentRaw = signals.currentRaw
        telemetry.batteryTelemetry.currentAmperes = signals.currentAmperes
        telemetry.batteryTelemetry.positiveBMS = bmsTelemetry(signals.positive)
        telemetry.batteryTelemetry.negativeBMS = bmsTelemetry(signals.negative)
        telemetry.batteryTelemetry.signalsUpdatedAt = date
        recalculatePower(in: &telemetry, date: date)
    }

    private func apply(_ speed: StarkSpeedPayload, to telemetry: inout BikeTelemetry) {
        telemetry.speed = .known(kmh: speed.speedKmh, kmhX10: speed.speedKmhX10)
        telemetry.motorRPM = .known(speed.motorRPM)
    }

    private func apply(_ totals: StarkLiveTotalsPayload, to telemetry: inout BikeTelemetry) {
        telemetry.odometer = .known(
            kilometers: totals.odometerKilometers,
            centiKilometers: totals.odometerCentiKilometers
        )
    }

    private func apply(
        _ configuration: StarkPowerModeConfigurationPayload,
        to telemetry: inout BikeTelemetry
    ) {
        var current = telemetry.powerModeConfigurations[configuration.mapIndex]
            ?? BikePowerModeConfiguration(mapIndex: configuration.mapIndex)
        current.horsepower = configuration.horsepower
        current.regenerativeBrakingPercent = configuration.regenerativeBrakingPercent
        telemetry.powerModeConfigurations[configuration.mapIndex] = current
        console(
            "domain power map=\(configuration.mapIndex) "
                + "active=\(telemetry.mode.displayIndex.map(String.init) ?? "unknown") "
                + "activeConfig=\(telemetry.mode.powerModeConfigurationIndex.map(String.init) ?? "unknown")"
        )
        if configuration.horsepower > 60 {
            promoteAlpha(evidence: .powerAboveStandard, telemetry: &telemetry)
        }
    }

    private func apply(
        _ configuration: StarkTractionControlConfigurationPayload,
        to telemetry: inout BikeTelemetry
    ) {
        var current = telemetry.powerModeConfigurations[configuration.mapIndex]
            ?? BikePowerModeConfiguration(mapIndex: configuration.mapIndex)
        current.powerTractionPercent = configuration.powerPercent
        current.brakingTractionPercent = configuration.brakingPercent
        telemetry.powerModeConfigurations[configuration.mapIndex] = current
        console(
            "domain TC map=\(configuration.mapIndex) "
                + "active=\(telemetry.mode.displayIndex.map(String.init) ?? "unknown") "
                + "activeConfig=\(telemetry.mode.powerModeConfigurationIndex.map(String.init) ?? "unknown")"
        )
        if configuration.powerRaw != 0 || configuration.brakingRaw != 0 {
            promoteAlpha(evidence: .tractionControlConfigured, telemetry: &telemetry)
        }
    }

    private func promoteAlpha(evidence: BikeAlphaEvidence, telemetry: inout BikeTelemetry) {
        var evidenceSet = telemetry.detectedPowerTier.alphaEvidence
        evidenceSet.insert(evidence)
        telemetry.detectedPowerTier = .alpha(evidence: evidenceSet)
    }

    private func console(_ message: String) {
        BikePowerModeDebugLog.log(message)
    }

    private func crawlState(isActive: Bool, isForward: Bool) -> BikeCrawlState {
        guard isActive else { return .inactive }
        return isForward ? .forward : .reverse
    }

    private func healthLevel(percent: Int?) -> HealthLevel {
        guard let percent else { return .unknown }
        return .known(percent: percent)
    }

    private func bmsTelemetry(_ payload: StarkBMSSignalsPayload) -> BikeBMSSignalsTelemetry {
        BikeBMSSignalsTelemetry(
            dcBusRaw: payload.dcBusRaw,
            dcBusVolts: payload.dcBusVolts,
            temperatureRaw: payload.temperatureRaw,
            temperatureCelsius: payload.temperatureCelsius,
            humidityRaw: payload.humidityRaw,
            humidityPercent: payload.humidityPercent
        )
    }

    private func recalculatePower(in telemetry: inout BikeTelemetry, date: Date) {
        guard let dcBusVolts = telemetry.batteryTelemetry.dcBusVolts,
              let currentAmperes = telemetry.batteryTelemetry.currentAmperes
        else {
            telemetry.powerTelemetry.electricalPowerWatts = nil
            telemetry.powerTelemetry.calculatedPowerUpdatedAt = nil
            return
        }
        let calculation = powerCalculator.calculate(
            dcBusVolts: dcBusVolts,
            batteryCurrentAmperes: currentAmperes
        )
        telemetry.powerTelemetry.electricalPowerWatts = calculation.electricalPowerWatts
        telemetry.powerTelemetry.calculatedPowerUpdatedAt = date
    }
}
