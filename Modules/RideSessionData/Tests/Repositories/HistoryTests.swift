import Foundation
import RideSessionDomain
import Testing

@MainActor
@Suite("SwiftData ride history")
struct RideTripHistoryTests {
    @Test("Isolates history by VIN")
    func isolatesTwoVehicles() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let first = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: UUID(),
            distance: 4
        )
        let second = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.secondVIN),
            sessionID: UUID(),
            distance: 8
        )
        await testContext.repository.completeTrip(first, at: first.updatedAt)
        await testContext.repository.completeTrip(second, at: second.updatedAt)

        let firstHistory = try await testContext.repository.loadCompletedTrips(
            vin: RideSessionDataFixtures.firstVIN
        )
        let secondHistory = try await testContext.repository.loadCompletedTrips(
            vin: RideSessionDataFixtures.secondVIN
        )

        #expect(firstHistory.map(\.id) == [first.id])
        #expect(secondHistory.map(\.id) == [second.id])
    }

    @Test("Keeps completed history beyond one hundred trips")
    func retainsAllHistoryPerVIN() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        for index in 0 ... 100 {
            let date = Date(timeIntervalSince1970: Double(index))
            let trip = RideSessionDataFixtures.makeTrip(
                identity: .vin(RideSessionDataFixtures.firstVIN),
                sessionID: UUID(),
                startedAt: date
            )
            await testContext.repository.completeTrip(trip, at: date.addingTimeInterval(1))
        }

        let history = try await testContext.repository.loadCompletedTrips(
            vin: RideSessionDataFixtures.firstVIN
        )
        #expect(history.count == 101)
        #expect(history.first?.startedAt == Date(timeIntervalSince1970: 100))
        #expect(history.last?.startedAt == Date(timeIntervalSince1970: 0))
    }

    @Test("Loads a completed ride detail with its energy buckets")
    func loadsCompletedDetailWithBuckets() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let bucket = RideEnergyBucket(
            startedAt: .distantPast,
            startDistanceKilometers: 4,
            endDistanceKilometers: 4.25,
            stateOfChargePercent: 72,
            consumedEnergyWattHours: 18,
            recoveredEnergyWattHours: 2
        )
        let trip = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: UUID(),
            startedAt: .distantPast,
            buckets: [bucket]
        )
        await testContext.repository.completeTrip(trip, at: .distantFuture)

        let detail = try await testContext.repository.loadCompletedTrip(
            id: trip.id,
            vin: RideSessionDataFixtures.firstVIN
        )

        #expect(detail?.energyBuckets == [bucket])
        #expect(try await testContext.repository.loadCompletedTrip(
            id: trip.id,
            vin: RideSessionDataFixtures.secondVIN
        ) == nil)
    }

    @Test("Deletes only the matching completed ride and its detail")
    func deletesCompletedRide() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let deletedBucket = RideSessionDataFixtures.makeBucket(startedAt: .distantPast)
        let retainedBucket = RideSessionDataFixtures.makeBucket(
            startedAt: Date(timeIntervalSince1970: 2_000)
        )
        let completed = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: UUID(),
            buckets: [deletedBucket]
        )
        let retained = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: 2_000),
            buckets: [retainedBucket]
        )
        let active = RideSessionDataFixtures.makeTrip(
            identity: .vin(RideSessionDataFixtures.firstVIN),
            sessionID: UUID()
        )
        await testContext.repository.completeTrip(completed, at: completed.updatedAt)
        await testContext.repository.completeTrip(retained, at: retained.updatedAt)
        await testContext.repository.saveActiveTrip(active)

        #expect(await testContext.repository.deleteCompletedTrip(
            id: completed.id,
            vin: RideSessionDataFixtures.secondVIN
        ) == false)
        #expect(await testContext.repository.deleteCompletedTrip(
            id: active.id,
            vin: RideSessionDataFixtures.firstVIN
        ) == false)
        #expect(await testContext.repository.deleteCompletedTrip(
            id: completed.id,
            vin: RideSessionDataFixtures.firstVIN
        ))
        #expect(try await testContext.repository.loadCompletedTrip(
            id: completed.id,
            vin: RideSessionDataFixtures.firstVIN
        ) == nil)
        #expect(try await testContext.repository.loadCompletedTrip(
            id: retained.id,
            vin: RideSessionDataFixtures.firstVIN
        )?.energyBuckets == [retainedBucket])
        #expect(await testContext.repository.prepare(context: .init(
            applicationSessionID: active.applicationSessionID,
            vehicleIdentity: active.vehicleIdentity
        ))?.id == active.id)
    }

    @Test("Round trips every completed ride field and its buckets")
    func roundTripsFullyPopulatedCompletedRide() async throws {
        let testContext = try RideSessionDataTestFactory.makeContext()
        let trip = RideSessionDataFixtures.makeFullyPopulatedCompletedTrip()

        #expect(await testContext.repository.completeTrip(trip, at: .distantFuture))

        let restored = try await testContext.repository.loadCompletedTrip(
            id: trip.id,
            vin: RideSessionDataFixtures.firstVIN
        )
        #expect(restored == trip)
    }
}
