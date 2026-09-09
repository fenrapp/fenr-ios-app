import BikeDomain
import SettingsDomain
import VehicleSession

enum ChargingTemperatureReportFixtures {
    static let normal = Array(repeating: 23.0, count: 12)
    static let zeroFilled = [23.0, 23.0] + Array(repeating: 0.0, count: 10)

    static func snapshot(
        units: MeasurementSystem, hasReceivedSettings: Bool = true
    ) -> VehicleSessionSnapshot {
        let base = DashboardMappingSnapshots.charging(settings: .init(measurementSystem: units))
        var health = base.batteryHealth
        health.temperatures = normal.enumerated().map { .init(position: $0.offset + 1, celsius: $0.element) }
        return .init(
            telemetry: base.telemetry, connection: base.connection, settings: base.settings,
            profile: base.profile, batteryHealth: health, batteryHealthMonitoringState: .active,
            hasReceivedSettings: hasReceivedSettings, hasReceivedProfile: true,
            isCanonicalTelemetryAvailable: true
        )
    }
}
