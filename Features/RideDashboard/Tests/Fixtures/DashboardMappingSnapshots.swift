import BikeDomain
import SettingsDomain
import VehicleSession

enum DashboardMappingSnapshots {
    static let vin = "FENRTEST000000001"
    static let otherVIN = "FENRTEST000000002"

    static func ride(
        speed: Double = 20, settings: AppSettings = .init(measurementSystem: .metric),
        vin: String = DashboardMappingSnapshots.vin, motion: VehicleMotionSnapshot = .init(), canonical: Bool = true
    ) -> VehicleSessionSnapshot {
        let base = ridingSnapshot(speed: speed)
        return .init(
            telemetry: base.telemetry, connection: base.connection, settings: settings,
            profile: .init(vin: vin), resolvedSpeedKilometersPerHour: speed, motion: motion,
            hasReceivedSettings: true, hasReceivedProfile: true, isCanonicalTelemetryAvailable: canonical
        )
    }

    static func charging(
        settings: AppSettings = .init(measurementSystem: .metric), vin: String = DashboardMappingSnapshots.vin,
        motion: VehicleMotionSnapshot = .init(), watts: Double = 1_000, canonical: Bool = true
    ) -> VehicleSessionSnapshot {
        var health = ChargingObservationData.chargingHealth
        health.chargingStatus = .init(
            requestedCurrentAmperes: 2.5, reportedCurrentAmperes: 2.5, maximumCurrentAmperes: 20,
            maximumPowerWatts: watts, targetCellVoltageVolts: 4.275,
            maximumStateOfChargePercent: 100, chargerType: .backpack
        )
        return .init(
            telemetry: .init(
                batteryLevel: .known(percent: 62), statusFlags: .init(isChargerConnected: true),
                lastUpdated: .init(timeIntervalSinceReferenceDate: 1)
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")), settings: settings,
            profile: .init(vin: vin), batteryHealth: health, batteryHealthMonitoringState: .active,
            motion: motion, hasReceivedSettings: true, hasReceivedProfile: true,
            isCanonicalTelemetryAvailable: canonical
        )
    }
}
