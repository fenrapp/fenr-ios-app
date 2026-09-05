import EnvironmentData
import MaintenanceData
import RideSessionData

@MainActor
struct ProductionAppStorageFactory {
    let makeRides: () throws -> SwiftDataRideTripRepository
    let makeMaintenance: () throws -> SwiftDataMaintenanceRepository
    let makeCalibration: () throws -> SwiftDataVehicleMotionCalibrationRepository

    func make() throws -> ProductionAppStorage {
        let rides = try makeRides()
        let maintenance = try makeMaintenance()
        let calibration = try makeCalibration()
        return ProductionAppStorage(rides: rides, maintenance: maintenance, calibration: calibration)
    }

    static var live: Self {
        Self(
            makeRides: {
                SwiftDataRideTripRepository(
                    modelContainer: try SwiftDataRideTripRepository.makeModelContainer(),
                    mapper: RideTripRecordMapper(),
                    energyBucketMapper: RideEnergyBucketRecordMapper()
                )
            },
            makeMaintenance: { try MaintenanceRepositoryFactory.make() },
            makeCalibration: {
                try SwiftDataVehicleMotionCalibrationRepository(mapper: VehicleMotionCalibrationRecordMapper())
            }
        )
    }
}
