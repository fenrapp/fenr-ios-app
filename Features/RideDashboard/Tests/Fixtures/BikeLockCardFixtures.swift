import BikeDomain
import Foundation
import SettingsDomain
import VehicleSession

enum BikeLockCardFixtures {
    static let vin = "FENRTEST000000001"

    static func snapshot(
        vin: String = vin,
        connectionState: ConnectionState = .receivingTelemetry(peripheralName: "Test Bike"),
        speed: Double? = 0,
        isInGear: Bool = false,
        isCharging: Bool = false,
        settings: AppSettings = .init()
    ) -> VehicleSessionSnapshot {
        .init(
            telemetry: .init(
                statusFlags: .init(
                    isOn: false,
                    isCharging: isCharging,
                    isChargerConnected: isCharging,
                    isInGear: isInGear
                ),
                lastUpdated: Date()
            ),
            connection: .init(state: connectionState),
            settings: settings,
            profile: .init(vin: vin),
            resolvedSpeedKilometersPerHour: speed,
            hasReceivedSettings: true,
            hasReceivedProfile: true
        )
    }
}
