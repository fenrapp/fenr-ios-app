import Foundation
@testable import RideSessionData
import RideSessionDomain
import Testing

@MainActor
@Suite("SwiftData ride trip sessions")
struct RideTripSessionTests {
    @Test("Restores a temporary trip only within its application session")
    func restoresTemporaryIdentityInSameSession() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let context = BikeSessionContext(
            applicationSessionID: UUID(),
            vehicleIdentity: .temporary(UUID())
        )
        let trip = RideSessionDataFixtures.makeTrip(
            identity: context.vehicleIdentity,
            sessionID: context.applicationSessionID
        )
        await testContext.repository.saveActiveTrip(trip)

        let restored = await testContext.repository.prepare(context: context)

        #expect(restored?.id == trip.id)
        #expect(restored?.isAwaitingElectricalRebase == true)
        #expect(restored?.maximumLeftLeanDegrees == 31)
        #expect(restored?.maximumUphillPitchDegrees == 12)
        #expect(restored?.attitudeSource == .bikeIMUBetaV1)
    }

    @Test("Deletes temporary data from previous application sessions")
    func deletesExpiredTemporaryIdentity() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let expiredSessionID = UUID()
        let trip = RideSessionDataFixtures.makeTrip(
            identity: .temporary(UUID()),
            sessionID: expiredSessionID,
            buckets: [RideSessionDataFixtures.makeBucket()]
        )
        await testContext.repository.saveActiveTrip(trip)
        let orphanTripID = UUID()
        let orphan = RideSessionDataTestFactory.makeEnergyBucketRecord(
            tripID: orphanTripID,
            identityKind: RideTripRecordMapper.Constants.temporaryKind,
            identityValue: UUID().uuidString,
            applicationSessionID: expiredSessionID
        )
        try testContext.persist(energyBucketRecords: [orphan])

        let context = BikeSessionContext(
            applicationSessionID: UUID(),
            vehicleIdentity: .temporary(UUID())
        )
        let restored = await testContext.repository.prepare(context: context)

        #expect(restored == nil)
        #expect(try testContext.tripSnapshots().isEmpty)
        #expect(try testContext.energyBucketSnapshots().isEmpty)
    }

    @Test("Atomically archives a reset trip and stores its replacement")
    func resetsTripAtomically() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let sessionID = UUID()
        let identity = RideVehicleIdentity.vin(RideSessionDataFixtures.firstVIN)
        let original = RideSessionDataFixtures.makeTrip(identity: identity, sessionID: sessionID)
        let replacement = RideTrip(
            vehicleIdentity: identity,
            applicationSessionID: sessionID,
            startedAt: original.updatedAt
        )

        await testContext.repository.resetTrip(
            completing: original,
            starting: replacement,
            at: original.updatedAt
        )

        let history = try await testContext.repository.loadCompletedTrips(
            vin: RideSessionDataFixtures.firstVIN
        )
        let restored = await testContext.repository.prepare(context: .init(
            applicationSessionID: sessionID,
            vehicleIdentity: identity
        ))
        #expect(history.map(\.id) == [original.id])
        #expect(restored?.id == replacement.id)
    }

    @Test("Rejects a finalized ride as active without persisting it")
    func rejectsFinalizedActiveTrip() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let trip = RideSessionDataFixtures.makeFullyPopulatedCompletedTrip()

        #expect(await testContext.repository.saveActiveTrip(trip) == false)
        #expect(try await testContext.repository.loadCompletedTrips(
            vin: RideSessionDataFixtures.firstVIN
        ).isEmpty)
        #expect(try testContext.tripSnapshots().isEmpty)
        #expect(try testContext.energyBucketSnapshots().isEmpty)
    }

    @Test("Discards another same-session temporary ride and its buckets")
    func discardsSameSessionTemporaryTripAndBuckets() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let applicationSessionID = UUID()
        let retainedIdentity = RideVehicleIdentity.temporary(UUID())
        let retained = RideSessionDataFixtures.makeTrip(
            identity: retainedIdentity,
            sessionID: applicationSessionID,
            startedAt: Date(timeIntervalSince1970: 1_000),
            buckets: [RideSessionDataFixtures.makeBucket()]
        )
        let discarded = RideSessionDataFixtures.makeTrip(
            identity: .temporary(UUID()),
            sessionID: applicationSessionID,
            startedAt: Date(timeIntervalSince1970: 2_000),
            buckets: [RideSessionDataFixtures.makeBucket(startedAt: Date(timeIntervalSince1970: 2_000))]
        )
        await testContext.repository.saveActiveTrip(retained)
        await testContext.repository.saveActiveTrip(discarded)

        let restored = await testContext.repository.prepare(context: .init(
            applicationSessionID: applicationSessionID,
            vehicleIdentity: retainedIdentity
        ))
        let trips = try testContext.tripSnapshots()
        let buckets = try testContext.energyBucketSnapshots()

        #expect(restored?.id == retained.id)
        #expect(trips.map(\.id) == [retained.id])
        #expect(buckets.map(\.tripID) == [retained.id])
    }

    @Test("Invalid persisted identities cannot restore and lose their exact buckets")
    func removesInvalidPersistedIdentitiesAndBuckets() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let applicationSessionID = UUID()
        let identities = [
            (kind: "unsupported", value: "value"),
            (kind: RideTripRecordMapper.Constants.vinKind, value: ""),
            (kind: RideTripRecordMapper.Constants.temporaryKind, value: "malformed")
        ]
        let tripRecords = identities.map { identity in
            RideSessionDataTestFactory.makeTripRecord(
                identityKind: identity.kind,
                identityValue: identity.value,
                applicationSessionID: applicationSessionID
            )
        }
        let buckets = zip(tripRecords, identities).map { record, identity in
            RideSessionDataTestFactory.makeEnergyBucketRecord(
                tripID: record.id,
                identityKind: identity.kind,
                identityValue: identity.value,
                applicationSessionID: applicationSessionID
            )
        }
        try testContext.persist(tripRecords: tripRecords, energyBucketRecords: buckets)

        let restored = await testContext.repository.prepare(context: .init(
            applicationSessionID: applicationSessionID,
            vehicleIdentity: .temporary(UUID())
        ))

        #expect(restored == nil)
        #expect(try testContext.tripSnapshots().isEmpty)
        #expect(try testContext.energyBucketSnapshots().isEmpty)
    }
}
