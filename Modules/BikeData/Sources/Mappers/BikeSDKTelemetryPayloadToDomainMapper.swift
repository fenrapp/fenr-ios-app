import BikeDomain
import BikeSDK
import Foundation
import StarkProtocol

public struct BikeSDKTelemetryPayloadToDomainMapper: Sendable {
    public init() {}

    public func apply(_ payload: BikeSDKTelemetryPayload, to telemetry: inout BikeTelemetry, date: Date) {
        switch payload {
        case .battery(let battery):
            telemetry.batteryLevel = .known(percent: battery.stateOfChargePercent)
            telemetry.healthLevel = healthLevel(percent: battery.stateOfHealthPercent)
        case .status(let status):
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
            telemetry.odometer = .known(
                kilometers: totals.odometerKilometers,
                centiKilometers: totals.odometerCentiKilometers
            )
        case .inverterTemperatures(let temperatures):
            telemetry.inverterTemperatureRawValues = temperatures.rawValues
            telemetry.inverterTemperaturesCelsius = temperatures.celsius
        case .vin(let vin):
            telemetry.vin = vin
        case .cellVoltages, .batteryTemperatures, .batteryBalancing, .charger, .throttle, .imu:
            break
        }
        telemetry.lastUpdated = date
    }

    private func apply(_ speed: StarkSpeedPayload, to telemetry: inout BikeTelemetry) {
        telemetry.speed = .known(kmh: speed.speedKmh, kmhX10: speed.speedKmhX10)
        telemetry.motorRPM = .known(speed.motorRPM)
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
}
