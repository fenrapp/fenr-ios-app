import Foundation
import SwiftData

enum PreAltitudeStoreFactory {
    @MainActor
    static func create(at url: URL, tripID: UUID, sessionID: UUID) throws {
        let schema = Schema([
            PreAltitudeRideSchema.RideTripRecord.self, PreAltitudeRideSchema.RideEnergyBucketRecord.self
        ])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration("RideTripsV4", schema: schema, url: url)
        )
        let context = ModelContext(container)
        let record = PreAltitudeRideSchema.RideTripRecord(
            id: tripID, vehicleIdentityKind: "vin", vehicleIdentityValue: "FENRTEST000000001",
            applicationSessionID: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_000), updatedAt: Date(timeIntervalSince1970: 1_010)
        )
        record.distanceKilometers = 12
        context.insert(record)
        try context.save()
    }
}
