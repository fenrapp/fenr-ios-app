import Foundation
import RideSessionDomain

actor NavigationRangeRepository: RideTripRepository {
    let trips: [RideTrip]
    private var pendingRead: CheckedContinuation<Void, Never>?
    private var shouldBlock = false
    private(set) var loadCount = 0
    var isBlocked: Bool { pendingRead != nil }

    init(trips: [RideTrip]) { self.trips = trips }
    func blockNextRead() { shouldBlock = true }
    func releaseRead() {
        pendingRead?.resume()
        pendingRead = nil
    }

    func loadCompletedTrips(vin: String) async -> [RideTrip] {
        loadCount += 1
        if shouldBlock {
            shouldBlock = false
            await withCheckedContinuation { pendingRead = $0 }
        }
        return trips.filter { $0.confirmedVIN == vin }
    }

    func prepare(context: BikeSessionContext) -> RideTrip? { nil }
    func saveActiveTrip(_ trip: RideTrip) -> Bool { false }
    func completeTrip(_ trip: RideTrip, at date: Date) -> Bool { false }
    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) -> Bool { false }
}
