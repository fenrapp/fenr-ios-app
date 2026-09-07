import Foundation
import RideSessionDomain

actor UnreadableDebugRideTripRepository: RideTripRepository {
    private(set) var completedTripCount = 0

    func prepare(context _: BikeSessionContext) -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) -> Bool { false }
    func completeTrip(_: RideTrip, at _: Date) -> Bool {
        completedTripCount += 1
        return true
    }
    func loadCompletedTrips(vin _: String) throws -> [RideTrip] {
        throw RideTripReadError.readFailed
    }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) -> Bool { false }
}
