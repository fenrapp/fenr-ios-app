import Foundation
@testable import MaintenanceData
import SwiftData

struct MaintenanceReadTestContext {
    let container: ModelContainer
    let repository: SwiftDataMaintenanceRepository

    @MainActor
    func persistRecord(vin: String, kind: String) throws -> UUID {
        let id = UUID()
        let context = ModelContext(container)
        let date = Date(timeIntervalSince1970: 100)
        context.insert(MaintenanceEntryRecord(
            id: id, vin: vin, kindRawValue: kind, matchingKey: kind,
            performedAt: date, createdAt: date, updatedAt: date
        ))
        try context.save()
        return id
    }

    @MainActor
    func storedKinds() throws -> [String] {
        try ModelContext(container).fetch(FetchDescriptor<MaintenanceEntryRecord>()).map(\.kindRawValue).sorted()
    }
}

enum MaintenanceReadTestFactory {
    static func makeContext() throws -> MaintenanceReadTestContext {
        let container = try ModelContainer(
            for: MaintenanceEntryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return MaintenanceReadTestContext(
            container: container,
            repository: SwiftDataMaintenanceRepository(
                store: MaintenanceStore(modelContainer: container), mapper: MaintenanceEntryRecordMapper()
            )
        )
    }
}
