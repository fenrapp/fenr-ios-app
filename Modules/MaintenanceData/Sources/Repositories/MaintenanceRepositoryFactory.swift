import Foundation
import SwiftData

public enum MaintenanceRepositoryFactory {
    public static func make(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> SwiftDataMaintenanceRepository {
        let configuration = storeURL.map { ModelConfiguration(Constants.storeName, url: $0) } ?? ModelConfiguration(
            Constants.storeName,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        let container = try ModelContainer(
            for: MaintenanceEntryRecord.self,
            configurations: configuration
        )
        return SwiftDataMaintenanceRepository(
            store: MaintenanceStore(modelContainer: container),
            mapper: MaintenanceEntryRecordMapper()
        )
    }
}

private extension MaintenanceRepositoryFactory {
    enum Constants {
        static let storeName = "MaintenanceV1"
    }
}
