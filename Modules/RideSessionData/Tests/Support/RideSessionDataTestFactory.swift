import Foundation
@testable import RideSessionData
import SwiftData

struct RideSessionDataTestContext {
    let modelContainer: ModelContainer
    let repository: SwiftDataRideTripRepository

    @MainActor
    func persist(
        tripRecords: [RideTripRecord] = [],
        energyBucketRecords: [RideEnergyBucketRecord] = []
    ) throws {
        let context = ModelContext(modelContainer)
        tripRecords.forEach(context.insert)
        energyBucketRecords.forEach(context.insert)
        try context.save()
    }

    @MainActor
    func tripSnapshots() throws -> [StoredRideTripRecord] {
        let context = ModelContext(modelContainer)
        return try context.fetch(FetchDescriptor<RideTripRecord>()).map(StoredRideTripRecord.init)
    }

    @MainActor
    func energyBucketSnapshots() throws -> [StoredRideEnergyBucketRecord] {
        let context = ModelContext(modelContainer)
        return try context.fetch(FetchDescriptor<RideEnergyBucketRecord>())
            .map(StoredRideEnergyBucketRecord.init)
    }
}

enum RideSessionDataTestFactory {
    static func makeContext() throws -> RideSessionDataTestContext {
        let modelContainer = try RideTripRepositoryFactory.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        return RideSessionDataTestContext(
            modelContainer: modelContainer,
            repository: RideTripRepositoryFactory.make(
                modelContainer: modelContainer,
                mapper: RideTripRecordMapper(),
                energyBucketMapper: RideEnergyBucketRecordMapper()
            )
        )
    }

    static func makeTripRecord(
        id: UUID = UUID(),
        identityKind: String,
        identityValue: String,
        applicationSessionID: UUID,
        startedAt: Date = RideSessionDataFixtures.referenceDate
    ) -> RideTripRecord {
        RideTripRecord(
            id: id,
            vehicleIdentityKind: identityKind,
            vehicleIdentityValue: identityValue,
            applicationSessionID: applicationSessionID,
            startedAt: startedAt,
            updatedAt: startedAt
        )
    }

    static func makeEnergyBucketRecord(
        id: UUID = UUID(),
        tripID: UUID,
        identityKind: String,
        identityValue: String,
        applicationSessionID: UUID,
        startedAt: Date = RideSessionDataFixtures.referenceDate
    ) -> RideEnergyBucketRecord {
        RideEnergyBucketRecord(
            id: id,
            tripID: tripID,
            vehicleIdentityKind: identityKind,
            vehicleIdentityValue: identityValue,
            applicationSessionID: applicationSessionID,
            startedAt: startedAt,
            updatedAt: startedAt
        )
    }
}

struct StoredRideTripRecord: Equatable {
    let id: UUID
    let vehicleIdentityKind: String
    let vehicleIdentityValue: String
    let applicationSessionID: UUID
    let endedAt: Date?

    init(_ record: RideTripRecord) {
        id = record.id
        vehicleIdentityKind = record.vehicleIdentityKind
        vehicleIdentityValue = record.vehicleIdentityValue
        applicationSessionID = record.applicationSessionID
        endedAt = record.endedAt
    }
}

struct StoredRideEnergyBucketRecord: Equatable {
    let id: UUID
    let tripID: UUID
    let vehicleIdentityKind: String
    let vehicleIdentityValue: String
    let applicationSessionID: UUID

    init(_ record: RideEnergyBucketRecord) {
        id = record.id
        tripID = record.tripID
        vehicleIdentityKind = record.vehicleIdentityKind
        vehicleIdentityValue = record.vehicleIdentityValue
        applicationSessionID = record.applicationSessionID
    }
}
