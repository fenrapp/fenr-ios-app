import Foundation
import RideSessionData
import RideSessionDomain
import Testing

@Suite("SwiftData ride trip repository")
@MainActor
struct SwiftDataRideTripRepositoryTests {
    @Test("Restores an active trip within the same application session")
    func restoresSameSession() async throws {
        let repository = try makeRepository()
        let sessionID = UUID()
        let trip = RideTrip(
            applicationSessionID: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_000),
            elapsedSeconds: 30,
            averageSpeedKilometersPerHour: 42,
            maximumSpeedKilometersPerHour: 60,
            accumulatedSpeedKilometersPerHourSeconds: 1_260,
            speedSampleDurationSeconds: 30
        )

        await repository.saveActiveTrip(trip)

        #expect(await repository.prepare(applicationSessionID: sessionID) == trip)
        #expect(await repository.loadCompletedTrips().isEmpty)
    }

    @Test("Archives an abandoned trip when a new application session starts")
    func archivesPreviousSession() async throws {
        let repository = try makeRepository()
        let trip = RideTrip(
            applicationSessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_120),
            elapsedSeconds: 120
        )
        await repository.saveActiveTrip(trip)

        let restored = await repository.prepare(applicationSessionID: UUID())
        let completed = await repository.loadCompletedTrips()

        #expect(restored == nil)
        #expect(completed.count == 1)
        #expect(completed.first?.id == trip.id)
        #expect(completed.first?.endedAt == trip.updatedAt)
    }

    @Test("Completing the same trip twice does not duplicate history")
    func completionIsIdempotent() async throws {
        let repository = try makeRepository()
        let trip = RideTrip(
            applicationSessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        let endedAt = Date(timeIntervalSince1970: 1_100)

        await repository.saveActiveTrip(trip)
        await repository.completeTrip(trip, at: endedAt)
        await repository.completeTrip(trip, at: endedAt)

        let completed = await repository.loadCompletedTrips()
        #expect(completed.count == 1)
        #expect(completed.first?.endedAt == endedAt)
    }

    @Test("Persists trips across repository contexts")
    func persistsAcrossRepositoryContexts() async throws {
        let container = try SwiftDataRideTripRepository.makeModelContainer(
            isStoredInMemoryOnly: true
        )
        let mapper = RideTripRecordMapper()
        let writer = SwiftDataRideTripRepository(
            modelContainer: container,
            mapper: mapper
        )
        let sessionID = UUID()
        let trip = RideTrip(
            applicationSessionID: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        await writer.saveActiveTrip(trip)

        let reader = SwiftDataRideTripRepository(
            modelContainer: container,
            mapper: mapper
        )

        #expect(await reader.prepare(applicationSessionID: sessionID) == trip)
    }

    @Test("Persists paused trip state")
    func persistsPausedState() async throws {
        let repository = try makeRepository()
        let sessionID = UUID()
        let date = Date(timeIntervalSince1970: 1_000)
        let pausedTrip = RideTrip(
            applicationSessionID: sessionID,
            startedAt: date
        ).paused(at: date.addingTimeInterval(30))

        await repository.saveActiveTrip(pausedTrip)

        let restored = await repository.prepare(applicationSessionID: sessionID)
        #expect(restored == pausedTrip)
        #expect(restored?.isPaused == true)
    }

    private func makeRepository() throws -> SwiftDataRideTripRepository {
        try SwiftDataRideTripRepository(
            mapper: RideTripRecordMapper(),
            isStoredInMemoryOnly: true
        )
    }
}
