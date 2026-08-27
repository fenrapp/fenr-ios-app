import Foundation
@testable import RideSession
import RideSessionDomain
import Testing

@Suite("Ride session persistence coordinator")
struct RideSessionPersistenceCoordinatorTests {
    @Test("Coalesces a burst to one active and the latest pending write")
    func coalescesPeriodicWrites() async {
        let repository = BlockingRideTripRepository()
        let coordinator = RideSessionPersistenceCoordinator(repository: repository)
        let trips = (1 ... 3).map(makeTrip)
        await repository.blockNextSave()

        await coordinator.saveActiveTrip(trips[0])
        await repository.waitForBlockedSave()
        await coordinator.saveActiveTrip(trips[1])
        await coordinator.saveActiveTrip(trips[2])
        await repository.releaseBlockedSave()
        await coordinator.flush()

        #expect(await repository.savedTripIDs() == [trips[0].id, trips[2].id])
        #expect(await repository.maximumConcurrentWrites() == 1)
    }

    @Test("A reset is an ordered barrier and flush waits for it")
    func resetIsBarrier() async {
        let repository = BlockingRideTripRepository()
        let coordinator = RideSessionPersistenceCoordinator(repository: repository)
        let active = makeTrip(index: 1)
        let replacement = makeTrip(index: 2)
        await repository.blockNextSave()

        await coordinator.saveActiveTrip(active)
        await repository.waitForBlockedSave()
        let resetTask = Task {
            await coordinator.resetTrip(
                completing: active,
                starting: replacement,
                at: .distantFuture
            )
        }
        await Task.yield()
        await repository.releaseBlockedSave()
        _ = await resetTask.value
        await coordinator.flush()

        #expect(await repository.events() == [.save(active.id), .reset(active.id, replacement.id)])
    }

    private func makeTrip(index: Int) -> RideTrip {
        RideTrip(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)")!,
            vehicleIdentity: .vin("TESTVIN0000000001"),
            applicationSessionID: UUID(),
            startedAt: .distantPast
        )
    }
}
