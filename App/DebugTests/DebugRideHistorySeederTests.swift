import BikeEmulator
import Foundation
import RideSessionData
import Testing

@Suite("Debug ride history seeder")
struct DebugRideHistorySeederTests {
    @Test("An unreadable history never triggers fixture writes")
    func readFailureDoesNotSeed() async {
        let repository = UnreadableDebugRideTripRepository()
        let seeder = DebugRideHistorySeeder(
            repository: repository,
            now: { Date(timeIntervalSinceReferenceDate: 100_000) }
        )

        await seeder.prepare()

        #expect(await repository.completedTripCount == 0)
    }

    @Test("Seeds debug ride history once and remains idempotent")
    func seedsDebugRideHistoryOnceAndIsIdempotent() async throws {
        let modelContainer = try RideTripRepositoryFactory.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let repository = RideTripRepositoryFactory.make(
            modelContainer: modelContainer,
            mapper: RideTripRecordMapper(),
            energyBucketMapper: RideEnergyBucketRecordMapper()
        )
        let seeder = DebugRideHistorySeeder(
            repository: repository,
            now: { Date(timeIntervalSinceReferenceDate: 100_000) }
        )

        await seeder.prepare()
        let firstIDs = try await repository.loadCompletedTrips(vin: BikeEmulatorIdentity.vin).map(\.id)
        await seeder.prepare()
        let secondIDs = try await repository.loadCompletedTrips(vin: BikeEmulatorIdentity.vin).map(\.id)

        #expect(firstIDs.count == 10)
        #expect(secondIDs == firstIDs)
    }
}
