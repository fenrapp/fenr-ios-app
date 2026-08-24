enum BatteryHealthChargePowerError: Error, CustomStringConvertible {
    case missingChargerTelemetry

    var description: String {
        switch self {
        case .missingChargerTelemetry:
            "Missing charger telemetry"
        }
    }
}
