import Foundation
import RideSessionDomain

struct StubRideTripRepository: RideTripRepository {
    let completedTrips: [RideTrip]

    init(completedTrips: [RideTrip] = []) {
        self.completedTrips = completedTrips
    }

    func prepare(context _: BikeSessionContext) async -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) async -> Bool { false }
    func completeTrip(_: RideTrip, at _: Date) async -> Bool { false }
    func loadCompletedTrips(vin _: String) async -> [RideTrip] { completedTrips }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) async -> Bool { false }
}
