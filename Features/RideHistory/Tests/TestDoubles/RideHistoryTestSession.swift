import Foundation
import RideSession
import RideSessionDomain
import TestSupport

actor RideHistoryTestSession: RideSessionService {
    private let hub = TestEventHub<RideSessionSnapshot>(bufferingPolicy: .unbounded)
    private let repository: any RideTripRepository
    private let operation: ControllableRideHistoryOperation
    private var snapshot: RideSessionSnapshot
    private var deleteSucceeds = true
    private var deletionResults: [UUID: Bool] = [:]

    init(
        repository: any RideTripRepository,
        snapshot: RideSessionSnapshot,
        operation: ControllableRideHistoryOperation
    ) {
        self.repository = repository
        self.snapshot = snapshot
        self.operation = operation
    }

    func observe() async -> AsyncStream<RideSessionSnapshot> {
        await hub.stream(replay: snapshot)
    }

    func start() {}
    func stop() {}
    func persistCurrentTrip() {}
    func completeCurrentTrip() {}
    func flush() {}
    func togglePauseCurrentTrip() {}
    func resetCurrentTrip() {}

    func deleteCompletedTrip(id: UUID, vin: String) async -> Bool {
        await operation.perform(.deletion(id))
        guard deletionResults[id] ?? deleteSucceeds,
              await repository.deleteCompletedTrip(id: id, vin: vin) else { return false }
        snapshot = RideSessionSnapshot(
            vehicleIdentity: snapshot.vehicleIdentity,
            measurementSystem: snapshot.measurementSystem,
            historyRevision: snapshot.historyRevision + 1
        )
        await hub.send(snapshot)
        return true
    }

    func send(_ snapshot: RideSessionSnapshot) async {
        self.snapshot = snapshot
        await hub.send(snapshot)
    }

    func setDeleteSucceeds(_ succeeds: Bool) {
        deleteSucceeds = succeeds
    }

    func setDeletionResults(_ results: [UUID: Bool]) {
        deletionResults = results
    }

    func waitForSubscriber() async {
        _ = await hub.waitForSubscriber()
    }
}
