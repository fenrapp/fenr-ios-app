import Foundation
import RideSessionDomain
import SwiftData

public final class SwiftDataRideTripRepository: RideTripRepository, Sendable {
    private let store: RideTripStore
    private let mapper: RideTripRecordMapper

    public convenience init(
        mapper: RideTripRecordMapper,
        isStoredInMemoryOnly: Bool = false
    ) throws {
        self.init(
            modelContainer: try Self.makeModelContainer(isStoredInMemoryOnly: isStoredInMemoryOnly),
            mapper: mapper
        )
    }

    public init(modelContainer: ModelContainer, mapper: RideTripRecordMapper) {
        store = RideTripStore(modelContainer: modelContainer)
        self.mapper = mapper
    }

    public static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            Constants.storeName,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: RideTripRecord.self, configurations: configuration)
    }

    public func prepare(context: BikeSessionContext) async -> RideTrip? {
        await store.prepare(context: context, mapper: mapper)
    }

    @discardableResult
    public func saveActiveTrip(_ trip: RideTrip) async -> Bool {
        await store.saveActiveTrip(trip, mapper: mapper)
    }

    @discardableResult
    public func completeTrip(_ trip: RideTrip, at date: Date) async -> Bool {
        await store.completeTrip(trip, at: date, mapper: mapper)
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
            mapper: mapper
        )
    }

    public func loadCompletedTrips(vin: String) async -> [RideTrip] {
        await store.loadCompletedTrips(vin: vin, mapper: mapper)
    }

    @discardableResult
    public func promoteTemporaryIdentity(_ temporaryID: UUID, toVIN vin: String) async -> Bool {
        await store.promoteTemporaryIdentity(temporaryID, toVIN: vin)
    }
}

private extension SwiftDataRideTripRepository {
    enum Constants {
        static let storeName = "RideTripsV2"
    }
}
