import Foundation
import RideSessionData
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

    @Test("Keeps only the newest one hundred trips for each VIN")
    func limitsHistoryPerVIN() async throws {
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
        #expect(history.count == 100)
        #expect(history.first?.startedAt == Date(timeIntervalSince1970: 100))
        #expect(history.last?.startedAt == Date(timeIntervalSince1970: 1))
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

    private func makeTrip(
        identity: RideVehicleIdentity,
        sessionID: UUID,
        startedAt: Date = Date(timeIntervalSince1970: 1_000),
        distance: Double = 2
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
            electricalExpectedSeconds: 100
        )
    }

    private func makeRepository() throws -> SwiftDataRideTripRepository {
        try SwiftDataRideTripRepository(
            mapper: RideTripRecordMapper(),
            isStoredInMemoryOnly: true
        )
    }

    private enum Constants {
        static let firstVIN = "TESTVIN0000000001"
        static let secondVIN = "TESTVIN0000000002"
    }
}
