import Foundation
@testable import RideSessionData
import RideSessionDomain
import Testing

@Suite("SwiftData ride trip repository")
struct SwiftDataRideTripRepositoryTests {
    @Test("Restores a temporary trip only within its application session")
    func restoresTemporaryIdentityInSameSession() async throws {
        let repository = try makeRepository()
        let context = BikeSessionContext(
            applicationSessionID: UUID(),
            vehicleIdentity: .temporary(UUID())
        )
        let trip = makeTrip(identity: context.vehicleIdentity, sessionID: context.applicationSessionID)
        await repository.saveActiveTrip(trip)

        let restored = await repository.prepare(context: context)

        #expect(restored?.id == trip.id)
        #expect(restored?.isAwaitingElectricalRebase == true)
        #expect(restored?.maximumLeftLeanDegrees == 31)
        #expect(restored?.maximumUphillPitchDegrees == 12)
        #expect(restored?.attitudeSource == .bikeIMUBetaV1)
    }

    @Test("Missing persisted attitude source is treated as legacy phone data")
    func mapsLegacyAttitudeSource() throws {
        let mapper = RideTripRecordMapper()
        let trip = makeTrip(identity: .vin(Constants.firstVIN), sessionID: UUID())
        let record = mapper.makeRecord(from: trip)
        record.attitudeSourceRawValue = nil

        #expect(mapper.mapToDomain(record)?.attitudeSource == .legacyPhone)
    }

    @Test("Deletes temporary data from previous application sessions")
    func deletesExpiredTemporaryIdentity() async throws {
        let repository = try makeRepository()
        let trip = makeTrip(identity: .temporary(UUID()), sessionID: UUID())
        await repository.saveActiveTrip(trip)

        let context = BikeSessionContext(
            applicationSessionID: UUID(),
            vehicleIdentity: .temporary(UUID())
        )
        let restored = await repository.prepare(context: context)

        #expect(restored == nil)
        #expect(await repository.loadCompletedTrips(vin: Constants.firstVIN).isEmpty)
    }

    @Test("Promotes all matching temporary records atomically")
    func promotesTemporaryIdentity() async throws {
        let repository = try makeRepository()
        let temporaryID = UUID()
        let trip = makeTrip(identity: .temporary(temporaryID), sessionID: UUID(), distance: 4)
        await repository.completeTrip(trip, at: trip.updatedAt)

        await repository.promoteTemporaryIdentity(temporaryID, toVIN: Constants.firstVIN)

        let completed = await repository.loadCompletedTrips(vin: Constants.firstVIN)
        #expect(completed.map(\.id) == [trip.id])
        #expect(completed.first?.vehicleIdentity == .vin(Constants.firstVIN))
    }

    @Test("Isolates history by VIN")
    func isolatesTwoVehicles() async throws {
        let repository = try makeRepository()
        let first = makeTrip(identity: .vin(Constants.firstVIN), sessionID: UUID(), distance: 4)
        let second = makeTrip(identity: .vin(Constants.secondVIN), sessionID: UUID(), distance: 8)
        await repository.completeTrip(first, at: first.updatedAt)
        await repository.completeTrip(second, at: second.updatedAt)

        let firstHistory = await repository.loadCompletedTrips(vin: Constants.firstVIN)
        let secondHistory = await repository.loadCompletedTrips(vin: Constants.secondVIN)

        #expect(firstHistory.map(\.id) == [first.id])
        #expect(secondHistory.map(\.id) == [second.id])
    }

    @Test("Keeps completed history beyond one hundred trips")
    func retainsAllHistoryPerVIN() async throws {
        let repository = try makeRepository()
        for index in 0 ... 100 {
            let date = Date(timeIntervalSince1970: Double(index))
            let trip = makeTrip(
                identity: .vin(Constants.firstVIN),
                sessionID: UUID(),
                startedAt: date,
                distance: 2
            )
            await repository.completeTrip(trip, at: date.addingTimeInterval(1))
        }

        let history = await repository.loadCompletedTrips(vin: Constants.firstVIN)
        #expect(history.count == 101)
        #expect(history.first?.startedAt == Date(timeIntervalSince1970: 100))
        #expect(history.last?.startedAt == Date(timeIntervalSince1970: 0))
    }

    @Test("Atomically archives a reset trip and stores its replacement")
    func resetsTripAtomically() async throws {
        let repository = try makeRepository()
        let sessionID = UUID()
        let identity = RideVehicleIdentity.vin(Constants.firstVIN)
        let original = makeTrip(identity: identity, sessionID: sessionID)
        let replacement = RideTrip(
            vehicleIdentity: identity,
            applicationSessionID: sessionID,
            startedAt: original.updatedAt
        )

        await repository.resetTrip(
            completing: original,
            starting: replacement,
            at: original.updatedAt
        )

        let history = await repository.loadCompletedTrips(vin: Constants.firstVIN)
        let restored = await repository.prepare(context: .init(
            applicationSessionID: sessionID,
            vehicleIdentity: identity
        ))
        #expect(history.map(\.id) == [original.id])
        #expect(restored?.id == replacement.id)
    }

    @Test("Persists compact energy buckets with the active trip")
    func persistsEnergyBuckets() async throws {
        let repository = try makeRepository()
        let context = BikeSessionContext(
            applicationSessionID: UUID(),
            vehicleIdentity: .vin(Constants.firstVIN)
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
        let trip = RideTrip(
            vehicleIdentity: context.vehicleIdentity,
            applicationSessionID: context.applicationSessionID,
            startedAt: .distantPast,
            energyBuckets: [bucket]
        )

        await repository.saveActiveTrip(trip)
        let restored = await repository.prepare(context: context)

        #expect(restored?.energyBuckets == [bucket])
    }

    @Test("Loads a completed ride detail with its energy buckets")
    func loadsCompletedDetailWithBuckets() async throws {
        let repository = try makeRepository()
        let bucket = RideEnergyBucket(
            startedAt: .distantPast,
            startDistanceKilometers: 4,
            endDistanceKilometers: 4.25,
            stateOfChargePercent: 72,
            consumedEnergyWattHours: 18,
            recoveredEnergyWattHours: 2
        )
        let trip = RideTrip(
            vehicleIdentity: .vin(Constants.firstVIN),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            energyBuckets: [bucket]
        )
        await repository.completeTrip(trip, at: .distantFuture)

        let detail = await repository.loadCompletedTrip(id: trip.id, vin: Constants.firstVIN)

        #expect(detail?.energyBuckets == [bucket])
        #expect(await repository.loadCompletedTrip(id: trip.id, vin: Constants.secondVIN) == nil)
    }

    @Test("Deletes only the matching completed ride and its detail")
    func deletesCompletedRide() async throws {
        let repository = try makeRepository()
        let deletedBucket = makeBucket(id: UUID(), startedAt: .distantPast)
        let retainedBucket = makeBucket(id: UUID(), startedAt: Date(timeIntervalSince1970: 2_000))
        let completed = makeTrip(
            identity: .vin(Constants.firstVIN),
            sessionID: UUID(),
            buckets: [deletedBucket]
        )
        let retained = makeTrip(
            identity: .vin(Constants.firstVIN),
            sessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: 2_000),
            buckets: [retainedBucket]
        )
        let active = makeTrip(identity: .vin(Constants.firstVIN), sessionID: UUID())
        await repository.completeTrip(completed, at: completed.updatedAt)
        await repository.completeTrip(retained, at: retained.updatedAt)
        await repository.saveActiveTrip(active)

        #expect(await repository.deleteCompletedTrip(id: completed.id, vin: Constants.secondVIN) == false)
        #expect(await repository.deleteCompletedTrip(id: active.id, vin: Constants.firstVIN) == false)
        #expect(await repository.deleteCompletedTrip(id: completed.id, vin: Constants.firstVIN))
        #expect(await repository.loadCompletedTrip(id: completed.id, vin: Constants.firstVIN) == nil)
        #expect(await repository.loadCompletedTrip(
            id: retained.id,
            vin: Constants.firstVIN
        )?.energyBuckets == [retainedBucket])
        #expect(await repository.prepare(context: .init(
            applicationSessionID: active.applicationSessionID,
            vehicleIdentity: active.vehicleIdentity
        ))?.id == active.id)
    }

    private func makeTrip(
        identity: RideVehicleIdentity,
        sessionID: UUID,
        startedAt: Date = Date(timeIntervalSince1970: 1_000),
        distance: Double = 2,
        buckets: [RideEnergyBucket] = []
    ) -> RideTrip {
        RideTrip(
            vehicleIdentity: identity,
            applicationSessionID: sessionID,
            startedAt: startedAt,
            updatedAt: startedAt.addingTimeInterval(100),
            distanceKilometers: distance,
            elapsedSeconds: 100,
            consumedEnergyWattHours: distance * 70,
            recoveredEnergyWattHours: 10,
            electricalObservedSeconds: 95,
            electricalExpectedSeconds: 100,
            maximumLeftLeanDegrees: 31,
            maximumRightLeanDegrees: 26,
            maximumUphillPitchDegrees: 12,
            maximumDownhillPitchDegrees: 9,
            energyBuckets: buckets
        )
    }

    private func makeBucket(id: UUID, startedAt: Date) -> RideEnergyBucket {
        RideEnergyBucket(
            id: id,
            startedAt: startedAt,
            startDistanceKilometers: 1,
            endDistanceKilometers: 1.25,
            stateOfChargePercent: 79,
            consumedEnergyWattHours: 22,
            recoveredEnergyWattHours: 3
        )
    }

    private func makeRepository() throws -> SwiftDataRideTripRepository {
        try SwiftDataRideTripRepository(
            mapper: RideTripRecordMapper(),
            energyBucketMapper: RideEnergyBucketRecordMapper(),
            isStoredInMemoryOnly: true
        )
    }

    private enum Constants {
        static let firstVIN = "TESTVIN0000000001"
        static let secondVIN = "TESTVIN0000000002"
    }
}
