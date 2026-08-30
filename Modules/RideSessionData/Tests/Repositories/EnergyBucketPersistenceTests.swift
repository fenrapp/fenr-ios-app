import Foundation
@testable import RideSessionData
import RideSessionDomain
import Testing

@MainActor
@Suite("SwiftData ride energy bucket persistence")
struct RideEnergyBucketPersistenceTests {
    @Test("Persists compact energy buckets with the active trip")
    func persistsEnergyBuckets() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let context = BikeSessionContext(
            applicationSessionID: UUID(),
            vehicleIdentity: .vin(RideSessionDataFixtures.firstVIN)
        )
        let bucket = RideEnergyBucket(
            startedAt: .distantPast,
            updatedAt: .distantFuture,
            startDistanceKilometers: 1,
            endDistanceKilometers: 1.25,
            stateOfChargePercent: 79,
            consumedEnergyWattHours: 22,
            recoveredEnergyWattHours: 3
        )
        let trip = RideSessionDataFixtures.makeTrip(
            identity: context.vehicleIdentity,
            sessionID: context.applicationSessionID,
            startedAt: .distantPast,
            buckets: [bucket]
        )

        await testContext.repository.saveActiveTrip(trip)
        let restored = await testContext.repository.prepare(context: context)

        #expect(restored?.energyBuckets == [bucket])
    }

    @Test("Promotes all matching temporary records atomically")
    func promotesTemporaryIdentity() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let temporaryID = UUID()
        let applicationSessionID = UUID()
        let bucket = RideSessionDataFixtures.makeBucket()
        let trip = RideSessionDataFixtures.makeTrip(
            identity: .temporary(temporaryID),
            sessionID: applicationSessionID,
            distance: 4,
            buckets: [bucket]
        )
        await testContext.repository.completeTrip(trip, at: trip.updatedAt)

        #expect(await testContext.repository.promoteTemporaryIdentity(
            temporaryID,
            toVIN: RideSessionDataFixtures.firstVIN
        ))

        let completed = await testContext.repository.loadCompletedTrips(
            vin: RideSessionDataFixtures.firstVIN
        )
        let tripRecord = try #require(testContext.tripSnapshots().first)
        let bucketRecord = try #require(testContext.energyBucketSnapshots().first)
        #expect(completed.map(\.id) == [trip.id])
        #expect(completed.first?.vehicleIdentity == .vin(RideSessionDataFixtures.firstVIN))
        #expect(tripRecord.vehicleIdentityKind == RideTripRecordMapper.Constants.vinKind)
        #expect(tripRecord.vehicleIdentityValue == RideSessionDataFixtures.firstVIN)
        #expect(tripRecord.applicationSessionID == applicationSessionID)
        #expect(bucketRecord.tripID == trip.id)
        #expect(bucketRecord.vehicleIdentityKind == RideTripRecordMapper.Constants.vinKind)
        #expect(bucketRecord.vehicleIdentityValue == RideSessionDataFixtures.firstVIN)
        #expect(bucketRecord.applicationSessionID == applicationSessionID)
    }
}
