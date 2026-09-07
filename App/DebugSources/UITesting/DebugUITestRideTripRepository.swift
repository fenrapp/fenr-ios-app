import Foundation
import RideSessionDomain

struct DebugUITestRideTripRepository: RideTripRepository {
    let repository: any RideTripRepository
    let controls: DebugUITestControls

    func prepare(context: BikeSessionContext) async -> RideTrip? {
        await repository.prepare(context: context)
    }

    func saveActiveTrip(_ trip: RideTrip) async -> Bool {
        await repository.saveActiveTrip(trip)
    }

    func completeTrip(_ trip: RideTrip, at date: Date) async -> Bool {
        await repository.completeTrip(trip, at: date)
    }

    func resetTrip(completing trip: RideTrip, starting replacement: RideTrip?, at date: Date) async -> Bool {
        await repository.resetTrip(completing: trip, starting: replacement, at: date)
    }

    func loadCompletedTrips(vin: String) async throws -> [RideTrip] {
        guard await !controls.historyReadFailure else { throw RideTripReadError.readFailed }
        return try await repository.loadCompletedTrips(vin: vin)
    }

    func loadCompletedTrip(id: UUID, vin: String) async throws -> RideTrip? {
        guard await !controls.historyReadFailure else { throw RideTripReadError.readFailed }
        return try await repository.loadCompletedTrip(id: id, vin: vin)
    }

    func deleteCompletedTrip(id: UUID, vin: String) async -> Bool {
        await repository.deleteCompletedTrip(id: id, vin: vin)
    }

    func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool {
        await repository.promoteTemporaryIdentity(temporaryID, toVIN: vin)
    }
}
