import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

enum NavigationRangeFixtures {
    static let vin = "FENRTEST000000001"

    static func history() -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(vin), applicationSessionID: UUID(),
            startedAt: .distantPast, endedAt: .distantPast,
            distanceKilometers: 10, consumedEnergyWattHours: 700,
            electricalObservedSeconds: 100, electricalExpectedSeconds: 100
        )
    }

    static func snapshot(
        vin: String = vin, units: MeasurementSystem = .metric,
        charge: Int? = 50, isCanonical: Bool = true, revision: Int = 0
    ) -> RideSessionSnapshot {
        .init(
            vehicleIdentity: .vin(vin), measurementSystem: units, historyRevision: revision,
            batteryStateOfChargePercent: charge, batteryCapacityWattHours: 7_200,
            isCanonicalTelemetryAvailable: isCanonical
        )
    }
}
