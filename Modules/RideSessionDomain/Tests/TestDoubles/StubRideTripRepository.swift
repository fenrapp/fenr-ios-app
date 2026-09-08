import Foundation
import RideSessionDomain

struct StubRideTripRepository: RideTripRepository {
    let completedTrips: [RideTrip]
    let readError: RideTripReadError?

    init(completedTrips: [RideTrip] = [], readError: RideTripReadError? = nil) {
        self.completedTrips = completedTrips
        self.readError = readError
    }

    func prepare(context _: BikeSessionContext) async -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) async -> Bool { false }
    func completeTrip(_: RideTrip, at _: Date) async -> Bool { false }
    func loadCompletedTrips(vin _: String) async throws -> [RideTrip] {
        if let readError { throw readError }
        return completedTrips
    }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) async -> Bool { false }
}
