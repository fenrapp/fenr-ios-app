import StarkProtocol

public enum BikeSDKTelemetryPayload: Equatable, Sendable {
    case battery(StarkBatteryPayload)
    case cellVoltages(StarkCellVoltagesPayload)
    case batteryTemperatures(StarkBatteryTemperaturesPayload)
    case batteryBalancing(StarkBatteryBalancingPayload)
    case charger(StarkChargerPayload)
    case status(StarkStatusPayload)
    case vcuBrake(StarkVCUBrakePayload)
    case map(Int)
    case speed(StarkSpeedPayload)
    case throttle(StarkThrottlePayload)
    case imu(StarkIMUPayload)
    case liveTotals(StarkLiveTotalsPayload)
    case inverterTemperatures(StarkInverterTemperaturesPayload)
    case vin(String)
}
