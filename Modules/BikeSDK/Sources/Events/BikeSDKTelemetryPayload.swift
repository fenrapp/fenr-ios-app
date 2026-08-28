import StarkProtocol

public enum BikeSDKTelemetryPayload: Equatable, Sendable {
    case battery(StarkBatteryPayload)
    case batteryStatus(StarkBatteryStatusPayload)
    case batteryParameters(StarkBatteryParametersPayload)
    case batterySignals(StarkBatterySignalsPayload)
    case cellVoltages(StarkCellVoltagesPayload)
    case batteryTemperatures(StarkBatteryTemperaturesPayload)
    case batteryBalancing(StarkBatteryBalancingPayload)
    case charger(StarkChargerPayload)
    case status(StarkStatusPayload)
    case vcuBrake(StarkVCUBrakePayload)
    case map(Int)
    case powerModeConfiguration(StarkPowerModeConfigurationPayload)
    case tractionControlConfiguration(StarkTractionControlConfigurationPayload)
    case speed(StarkSpeedPayload)
    case throttle(StarkThrottlePayload)
    case imu(StarkIMUPayload)
    case liveTotals(StarkLiveTotalsPayload)
    case liveEstimations(StarkLiveEstimationsPayload)
    case inverterTemperatures(StarkInverterTemperaturesPayload)
    case vin(String)
}
