import Foundation
import RideSessionDomain

actor RideHistoryTestRepository: RideTripRepository {
    private var trips: [RideTrip]

    init(trips: [RideTrip] = []) {
        self.trips = trips
    }

    func prepare(context _: BikeSessionContext) -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) -> Bool { true }
    func completeTrip(_: RideTrip, at _: Date) -> Bool { true }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) -> Bool { true }

    func loadCompletedTrips(vin: String) -> [RideTrip] {
        trips
            .filter { $0.confirmedVIN == vin && $0.endedAt != nil }
            .sorted { $0.startedAt > $1.startedAt }
            .map { $0.restoringEnergyBuckets([]) }
    }

    func loadCompletedTrip(id: UUID, vin: String) -> RideTrip? {
        trips.first { $0.id == id && $0.confirmedVIN == vin && $0.endedAt != nil }
    }

    func deleteCompletedTrip(id: UUID, vin: String) -> Bool {
        guard let index = trips.firstIndex(where: {
            $0.id == id && $0.confirmedVIN == vin && $0.endedAt != nil
        }) else { return false }
        trips.remove(at: index)
        return true
    }

    func replaceTrips(_ trips: [RideTrip]) {
        self.trips = trips
    }
}
