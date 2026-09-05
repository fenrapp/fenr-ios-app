import EnvironmentData
import MaintenanceData
import RideSessionData

struct ProductionAppStorage {
    let rides: SwiftDataRideTripRepository
    let maintenance: SwiftDataMaintenanceRepository
    let calibration: SwiftDataVehicleMotionCalibrationRepository
}
