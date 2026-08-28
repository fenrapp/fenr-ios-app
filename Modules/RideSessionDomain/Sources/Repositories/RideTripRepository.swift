import Foundation

public protocol RideTripRepository: Sendable {
    func prepare(context: BikeSessionContext) async -> RideTrip?
    @discardableResult
    func saveActiveTrip(_ trip: RideTrip) async -> Bool
    @discardableResult
    func completeTrip(_ trip: RideTrip, at date: Date) async -> Bool
    @discardableResult
    func resetTrip(completing trip: RideTrip, starting replacement: RideTrip?, at date: Date) async -> Bool
    func loadCompletedTrips(vin: String) async -> [RideTrip]
    func loadCompletedTrip(id: UUID, vin: String) async -> RideTrip?
    @discardableResult
    func deleteCompletedTrip(id: UUID, vin: String) async -> Bool
    @discardableResult
    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool
}

public extension RideTripRepository {
    func loadCompletedTrip(id: UUID, vin: String) async -> RideTrip? {
        await loadCompletedTrips(vin: vin).first { $0.id == id }
    }

    func deleteCompletedTrip(id _: UUID, vin _: String) async -> Bool {
        false
    }

    func resetTrip(
        completing trip: RideTrip,
        starting replacement: RideTrip?,
        at date: Date
    ) async -> Bool {
        let didComplete = await completeTrip(trip, at: date)
        if let replacement {
            return await saveActiveTrip(replacement) && didComplete
        }
        return didComplete
    }
}
