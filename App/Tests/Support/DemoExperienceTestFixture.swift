import Foundation
import MaintenanceData
import RideSessionData
import SettingsDomain

@MainActor
struct DemoExperienceTestFixture {
    let identity: DemoIdentity
    let directory: URL
    let factory: DemoExperienceFactory
    let notifications: DemoTestNotifications

    init(
        makeCredentialStore: @escaping @MainActor (String) -> any BikeLockCredentialStoring = { _ in
            DemoTestCredentialStore()
        }
    ) {
        let fileManager = FileManager()
        identity = DemoIdentity(id: UUID(), vin: "FENRTEST123456789", createdAt: Date())
        directory = fileManager.temporaryDirectory.appendingPathComponent("fenr-demo-tests-\(UUID().uuidString)")
        notifications = DemoTestNotifications()
        factory = DemoExperienceFactory(
            fileManager: fileManager, baseDirectory: directory, notifications: notifications,
            makeCredentialStore: makeCredentialStore
        )
    }

    func makeRides() throws -> SwiftDataRideTripRepository {
        SwiftDataRideTripRepository(
            modelContainer: try SwiftDataRideTripRepository.makeModelContainer(
                storeURL: directory.appendingPathComponent(identity.id.uuidString).appendingPathComponent("Rides.store")
            ),
            mapper: RideTripRecordMapper(), energyBucketMapper: RideEnergyBucketRecordMapper()
        )
    }

    func makeMaintenance() throws -> SwiftDataMaintenanceRepository {
        try MaintenanceRepositoryFactory.make(
            storeURL: directory.appendingPathComponent(identity.id.uuidString)
                .appendingPathComponent("Maintenance.store")
        )
    }
}
