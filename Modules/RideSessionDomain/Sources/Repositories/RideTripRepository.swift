import Foundation

public protocol RideTripRepository: Sendable {
    func prepare(applicationSessionID: UUID) async -> RideTrip?
    func saveActiveTrip(_ trip: RideTrip) async
    func completeTrip(_ trip: RideTrip, at date: Date) async
    func loadCompletedTrips() async -> [RideTrip]
}
