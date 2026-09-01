import BikeDomain
import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain

actor CurrentTripCardTripRepository: RideTripRepository {
    private var activeTrip: RideTrip?
    private var completedTrips: [RideTrip]
    private var completedTripLoadCount = 0

    init(completedTrips: [RideTrip] = []) {
        self.completedTrips = completedTrips
    }

    func prepare(context: BikeSessionContext) -> RideTrip? {
        guard activeTrip?.applicationSessionID == context.applicationSessionID,
              activeTrip?.vehicleIdentity == context.vehicleIdentity else { return nil }
        return activeTrip
    }

    func saveActiveTrip(_ trip: RideTrip) -> Bool {
        activeTrip = trip
        return true
    }

    func completeTrip(_ trip: RideTrip, at date: Date) -> Bool {
        activeTrip = nil
        completedTrips.removeAll { $0.id == trip.id }
        completedTrips.append(trip.completed(at: date))
        return true
    }

    func loadCompletedTrips(vin: String) -> [RideTrip] {
        completedTripLoadCount += 1
        return completedTrips.filter { $0.confirmedVIN == vin }
    }

    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) -> Bool {
        if activeTrip?.vehicleIdentity == .temporary(temporaryID) {
            activeTrip = activeTrip?.promotingVehicleIdentity(to: vin)
        }
        completedTrips = completedTrips.map {
            $0.vehicleIdentity == .temporary(temporaryID) ? $0.promotingVehicleIdentity(to: vin) : $0
        }
        return true
    }

    func currentActiveTrip() -> RideTrip? { activeTrip }
    func completionCount() -> Int { completedTrips.count }
    func loadCount() -> Int { completedTripLoadCount }
    func replaceCompletedTrips(with trips: [RideTrip]) { completedTrips = trips }

}

actor CurrentTripCardProfileRepository: BikeProfileRepository {
    func loadProfile() -> BikeProfile? { .init(vin: CurrentTripTestIdentity.vin) }
    func saveProfile(_: BikeProfile) {}
    func clearProfile() {}
}

enum CurrentTripTestIdentity {
    static let vin = "TESTVIN0000000001"
}

actor TestRideSessionService: RideSessionService {
    private var snapshot: RideSessionSnapshot
    private var observers: [UUID: AsyncStream<RideSessionSnapshot>.Continuation] = [:]
    private var pauseToggleCount = 0
    private var resetCount = 0
    private var recordedCommands: [TestRideSessionCommand] = []
    private let pauseCommandDelay: Duration

    init(
        snapshot: RideSessionSnapshot = .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            isCanonicalTelemetryAvailable: true
        ),
        pauseCommandDelay: Duration = .zero
    ) {
        self.snapshot = snapshot
        self.pauseCommandDelay = pauseCommandDelay
    }

    func observe() -> AsyncStream<RideSessionSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            observers[id] = continuation
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    func start() {}
    func stop() {}
    func persistCurrentTrip() {}
    func completeCurrentTrip() {}
    func flush() {}

    func togglePauseCurrentTrip() async {
        if pauseCommandDelay > .zero {
            try? await Task.sleep(for: pauseCommandDelay)
        }
        pauseToggleCount += 1
        recordedCommands.append(.togglePause)
    }

    func resetCurrentTrip() {
        resetCount += 1
        recordedCommands.append(.reset)
    }

    func send(_ snapshot: RideSessionSnapshot) {
        self.snapshot = snapshot
        observers.values.forEach { $0.yield(snapshot) }
    }

    func pauseCommands() -> Int { pauseToggleCount }
    func resetCommands() -> Int { resetCount }
    func commands() -> [TestRideSessionCommand] { recordedCommands }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}

enum TestRideSessionCommand: Equatable {
    case togglePause
    case reset
}
