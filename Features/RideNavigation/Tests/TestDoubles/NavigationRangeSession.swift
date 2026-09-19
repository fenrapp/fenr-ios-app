import Foundation
import RideSession
import TestSupport

actor NavigationRangeSession: RideSessionService {
    let events: TestEventHub<RideSessionSnapshot>
    private var snapshot: RideSessionSnapshot
    private(set) var lifecycleCalls = 0
    private(set) var observationCount = 0

    init(events: TestEventHub<RideSessionSnapshot>, snapshot: RideSessionSnapshot) {
        self.events = events
        self.snapshot = snapshot
    }

    func observe() async -> AsyncStream<RideSessionSnapshot> {
        observationCount += 1
        return await events.stream(replay: snapshot)
    }

    func send(_ snapshot: RideSessionSnapshot) async {
        self.snapshot = snapshot
        await events.send(snapshot)
    }

    func start() { lifecycleCalls += 1 }
    func stop() { lifecycleCalls += 1 }
    func persistCurrentTrip() {}
    func completeCurrentTrip() {}
    func flush() {}
    func togglePauseCurrentTrip() {}
    func resetCurrentTrip() {}
}
