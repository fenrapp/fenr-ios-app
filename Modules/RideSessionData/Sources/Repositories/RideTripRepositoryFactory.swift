import Foundation
import SwiftData

public enum RideTripRepositoryFactory {
    public static func make(
        modelContainer: ModelContainer,
        mapper: RideTripRecordMapper,
        energyBucketMapper: RideEnergyBucketRecordMapper
    ) -> SwiftDataRideTripRepository {
        SwiftDataRideTripRepository(
            store: RideTripStore(modelContainer: modelContainer),
            mapper: mapper,
            energyBucketMapper: energyBucketMapper
        )
    }

    public static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let configuration = storeURL.map { ModelConfiguration(Constants.storeName, url: $0) } ?? ModelConfiguration(
            Constants.storeName,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: RideTripRecord.self,
            RideEnergyBucketRecord.self,
            configurations: configuration
        )
    }

    private enum Constants {
        static let storeName = "RideTripsV4"
    }
}
