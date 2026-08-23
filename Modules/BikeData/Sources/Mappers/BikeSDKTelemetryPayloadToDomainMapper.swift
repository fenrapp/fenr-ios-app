import BikeDomain
import BikeSDK
import Foundation

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
        case .speed(let speed):
            telemetry.speed = .known(kmh: speed.speedKmh, kmhX10: speed.speedKmhX10)
            telemetry.motorRPM = .known(speed.motorRPM)
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

    private func crawlState(isActive: Bool, isForward: Bool) -> BikeCrawlState {
        guard isActive else { return .inactive }
        return isForward ? .forward : .reverse
    }

    private func healthLevel(percent: Int?) -> HealthLevel {
        guard let percent else { return .unknown }
        return .known(percent: percent)
    }
}
