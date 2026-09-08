import Foundation
import RideSession
import RideSessionDomain
import SettingsDomain

enum RangeMappingFixtures {
    enum TripChange: CaseIterable {
        case none, timestamps, distance, discharge, regeneration, bucketID, bucketStart, bucketEnd
        case bucketCharge, consumed, recovered
    }

    static func trip(_ change: TripChange = .none) -> RideTrip {
        let date = change == .timestamps ? Date.distantFuture : .distantPast
        return RideTrip(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            startedAt: date, updatedAt: date,
            distanceKilometers: change == .distance ? 3 : 2,
            maximumDischargePowerWatts: change == .discharge ? 14_000 : 12_000,
            maximumRegenerationPowerWatts: change == .regeneration ? 5_000 : 4_000,
            energyBuckets: [.init(
                id: UUID(uuidString: change == .bucketID
                    ? "00000000-0000-0000-0000-000000000004" : "00000000-0000-0000-0000-000000000003")!,
                startedAt: date, updatedAt: date,
                startDistanceKilometers: change == .bucketStart ? 0.2 : 0,
                endDistanceKilometers: change == .bucketEnd ? 3 : 2,
                stateOfChargePercent: change == .bucketCharge ? 40 : 50,
                consumedEnergyWattHours: change == .consumed ? 200 : 160,
                recoveredEnergyWattHours: change == .recovered ? 30 : 20
            )]
        )
    }

    static func snapshot(
        trip: RideTrip? = RangeMappingFixtures.trip(), units: MeasurementSystem = .metric,
        charge: Int = 60, capacity: Double = 7_200, vin: String = CurrentTripTestIdentity.vin,
        historyRevision: Int = 0
    ) -> RideSessionSnapshot {
        .init(
            trip: trip, vehicleIdentity: .vin(vin), measurementSystem: units, historyRevision: historyRevision,
            batteryStateOfChargePercent: charge, batteryCapacityWattHours: capacity,
            isCanonicalTelemetryAvailable: true
        )
    }

    static var irrelevantChanges: RideSessionSnapshot {
        .init(
            trip: trip(.timestamps), vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            resolvedSpeedKilometersPerHour: 75, speedSource: .gps, isGPSAvailable: true,
            livePowerSamples: [.init(date: .distantFuture, powerWatts: 5_000)], historyRevision: 10,
            batteryStateOfChargePercent: 60, batteryCapacityWattHours: 7_200,
            motion: .init(rollDegrees: 45, availability: .available), isCanonicalTelemetryAvailable: true
        )
    }
}
