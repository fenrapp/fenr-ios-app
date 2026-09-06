import BikeData
import EnvironmentData
import Foundation
import MaintenanceData
import RideNavigationData
import RideSessionData
import SettingsData

@MainActor
struct DemoIsolationTestFixture {
    let demo: DemoExperienceTestFixture
    let realSuite: String
    let realDirectory: URL

    init() throws {
        demo = DemoExperienceTestFixture()
        realSuite = "fenr.tests.real.\(UUID().uuidString)"
        realDirectory = demo.directory.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(at: realDirectory, withIntermediateDirectories: true)
    }

    nonisolated func defaults(suite: String) throws -> sending UserDefaults {
        guard let defaults = UserDefaults(suiteName: suite) else { throw DemoPreparationError.unavailableStorage }
        return defaults
    }

    func realRides() throws -> SwiftDataRideTripRepository {
        RideTripRepositoryFactory.make(
            modelContainer: try RideTripRepositoryFactory.makeModelContainer(
                storeURL: realDirectory.appendingPathComponent("Rides.store")
            ), mapper: RideTripRecordMapper(), energyBucketMapper: RideEnergyBucketRecordMapper()
        )
    }

    func realMaintenance() throws -> SwiftDataMaintenanceRepository {
        try MaintenanceRepositoryFactory.make(storeURL: realDirectory.appendingPathComponent("Maintenance.store"))
    }

    func calibration(directory: URL) throws -> SwiftDataVehicleMotionCalibrationRepository {
        try VehicleMotionCalibrationRepositoryFactory.make(
            mapper: VehicleMotionCalibrationRecordMapper(),
            storeURL: directory.appendingPathComponent("Calibration.store")
        )
    }

    func routes(directory: URL) -> FileRecordedRouteRepository {
        FileRecordedRouteRepository(
            fileManager: FileManager(), directoryURL: directory.appendingPathComponent("Routes"),
            codec: StoredRideRouteCodec()
        )
    }

    func mapLinks(suite: String) throws -> UserDefaultsIncomingMapLinkStore {
        UserDefaultsIncomingMapLinkStore(
            userDefaults: try defaults(suite: suite), encoder: JSONEncoder(), decoder: JSONDecoder()
        )
    }

    func cleanUp() throws {
        UserDefaults.standard.removePersistentDomain(forName: realSuite)
        UserDefaults.standard.removePersistentDomain(forName: demo.identity.suiteName)
        try FileManager.default.removeItem(at: demo.directory)
    }
}
