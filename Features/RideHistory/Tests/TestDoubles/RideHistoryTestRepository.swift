import Foundation
import RideSessionDomain

actor RideHistoryTestRepository: RideTripRepository {
    private let operation: ControllableRideHistoryOperation
    private var trips: [RideTrip]
    private var nextHistoryError: RideTripReadError?
    private var nextDetailError: RideTripReadError?

    init(
        trips: [RideTrip] = [],
        operation: ControllableRideHistoryOperation
    ) {
        self.trips = trips
        self.operation = operation
    }

    func prepare(context _: BikeSessionContext) -> RideTrip? { nil }
    func saveActiveTrip(_: RideTrip) -> Bool { true }
    func completeTrip(_: RideTrip, at _: Date) -> Bool { true }
    func promoteTemporaryIdentity(_: UUID, toVIN _: String) -> Bool { true }

    func loadCompletedTrips(vin: String) async throws -> [RideTrip] {
        let failure = nextHistoryError
        nextHistoryError = nil
        let result = trips
            .filter { $0.confirmedVIN == vin && $0.endedAt != nil }
            .sorted { $0.startedAt > $1.startedAt }
            .map { $0.restoringEnergyBuckets([]) }
        await operation.perform(.history)
        if let failure { throw failure }
        return result
    }

    func loadCompletedTrip(id: UUID, vin: String) async throws -> RideTrip? {
        let failure = nextDetailError
        nextDetailError = nil
        let result = trips.first { $0.id == id && $0.confirmedVIN == vin && $0.endedAt != nil }
        await operation.perform(.detail(id))
        if let failure { throw failure }
        return result
    }

    func deleteCompletedTrip(id: UUID, vin: String) -> Bool {
        guard let index = trips.firstIndex(where: {
            $0.id == id && $0.confirmedVIN == vin && $0.endedAt != nil
        }) else { return false }
        trips.remove(at: index)
        return true
    }

    func failNextHistory(_ error: RideTripReadError = .readFailed) { nextHistoryError = error }
    func failNextDetail(_ error: RideTripReadError = .readFailed) { nextDetailError = error }

    func replaceTrips(_ trips: [RideTrip]) {
        self.trips = trips
    }
}
