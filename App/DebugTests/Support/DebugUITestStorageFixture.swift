import Foundation
import MaintenanceData
import RideSessionData

struct DebugUITestStorageFixture {
    let session: DebugUITestSession
    let defaults: UserDefaults
    let profiles: DebugUITestProfileStore
    let rides: SwiftDataRideTripRepository
    let maintenance: SwiftDataMaintenanceRepository

    static func make(id: UUID, root: URL) throws -> Self {
        let session = DebugUITestSession(
            id: id, directory: root.appendingPathComponent(id.uuidString), resetsStorage: false
        )
        let defaults = try session.prepare(fileManager: .default, clearCredentials: { _ in })
        return Self(
            session: session,
            defaults: defaults,
            profiles: DebugUITestProfileStore(
                defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(), lock: NSLock()
            ),
            rides: RideTripRepositoryFactory.make(
                modelContainer: try RideTripRepositoryFactory.makeModelContainer(
                    storeURL: session.directory.appendingPathComponent("Rides.store")
                ),
                mapper: RideTripRecordMapper(), energyBucketMapper: RideEnergyBucketRecordMapper()
            ),
            maintenance: try MaintenanceRepositoryFactory.make(
                storeURL: session.directory.appendingPathComponent("Maintenance.store")
            )
        )
    }

    func clearDefaults() {
        defaults.removePersistentDomain(forName: session.suiteName)
    }
}
