import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

enum DashboardHistoryCardData {
    static func snapshot(
        vin: String = CurrentTripTestIdentity.vin,
        revision: Int = 0,
        isCanonical: Bool = true,
        measurementSystem: MeasurementSystem = .metric
    ) -> RideSessionSnapshot {
        .init(
            vehicleIdentity: .vin(vin),
            measurementSystem: measurementSystem,
            historyRevision: revision,
            batteryStateOfChargePercent: 60,
            batteryCapacityWattHours: 7_200,
            isCanonicalTelemetryAvailable: isCanonical
        )
    }

    static func trip() -> RideTrip {
        .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            endedAt: .distantPast,
            distanceKilometers: 12,
            consumedEnergyWattHours: 840,
            electricalObservedSeconds: 100,
            electricalExpectedSeconds: 100
        )
    }
}
