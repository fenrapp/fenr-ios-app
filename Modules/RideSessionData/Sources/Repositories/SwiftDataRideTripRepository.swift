import Foundation
import RideSessionDomain

public struct SwiftDataRideTripRepository: RideTripRepository, Sendable {
    private let store: RideTripStore
    private let mapper: RideTripRecordMapper
    private let energyBucketMapper: RideEnergyBucketRecordMapper

    init(
        store: RideTripStore,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) {
        self.store = store
        self.mapper = mapper
        self.energyBucketMapper = energyBucketMapper
    }

    public func prepare(context: BikeSessionContext) async -> RideTrip? {
        await store.prepare(context: context, mapper: mapper, energyBucketMapper: energyBucketMapper)
    }

    @discardableResult
    public func saveActiveTrip(_ trip: RideTrip) async -> Bool {
        await store.saveActiveTrip(trip, mapper: mapper, energyBucketMapper: energyBucketMapper)
    }

    @discardableResult
    public func completeTrip(_ trip: RideTrip, at date: Date) async -> Bool {
        await store.completeTrip(trip, at: date, mapper: mapper, energyBucketMapper: energyBucketMapper)
    }

    @discardableResult
    public func resetTrip(
        completing trip: RideTrip,
        starting replacement: RideTrip?,
        at date: Date
    ) async -> Bool {
        await store.resetTrip(
            completing: trip,
            starting: replacement,
            at: date,
            mapper: mapper,
            energyBucketMapper: energyBucketMapper
        )
    }

    public func loadCompletedTrips(vin: String) async throws -> [RideTrip] {
        try await store.loadCompletedTrips(vin: vin, mapper: mapper)
    }

    public func loadCompletedTrip(id: UUID, vin: String) async throws -> RideTrip? {
        try await store.loadCompletedTrip(
            id: id,
            vin: vin,
            mapper: mapper,
            energyBucketMapper: energyBucketMapper
        )
    }

    @discardableResult
    public func deleteCompletedTrip(id: UUID, vin: String) async -> Bool {
        await store.deleteCompletedTrip(id: id, vin: vin)
    }

    @discardableResult
    public func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool {
        await store.promoteTemporaryIdentity(temporaryID, toVIN: vin)
    }
}
