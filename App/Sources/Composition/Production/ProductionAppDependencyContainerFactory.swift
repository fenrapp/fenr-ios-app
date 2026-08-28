import BikeData
import BikeDiagnostics
import BikeDomain
import BLETraceDomain
import CoreLocation
import CoreMotion
import EnvironmentData
import Foundation
import RideSessionData
import SettingsData

@MainActor
enum ProductionAppDependencyContainerFactory {
    static func makeDefault() -> AppDependencyContainer {
        let bikeSDKContainer = BikeSDKDependencyContainer()
        let bikeDataContainer = BikeDataDependencyContainer()
        let bleTraceRepository = BLETraceDependencyContainer().makeRepository()
        let client = bikeSDKContainer.makeBikeTelemetryClient(traceRecorder: bleTraceRepository)
        let profileRepository = UserDefaultsBikeProfileRepository()
        let repository = bikeDataContainer.makeBikeRepository(
            client: client,
            profileRepository: profileRepository
        )
        let session = BikeSession(
            repository: repository,
            pinDeriver: bikeDataContainer.makeBikePinDeriver()
        )
        let chargeControl = ChargeControlDependencyContainer().makeSession(repository: repository)
        let settingsRepository = UserDefaultsAppSettingsRepository()
        let deviceSpeedRepository = CoreLocationDeviceSpeedRepository(
            locationManager: CLLocationManager()
        )
        let deviceMotionRepository = CoreMotionDeviceMotionRepository(
            motionManager: CMMotionManager(),
            operationQueue: OperationQueue(),
            now: Date.init
        )
        let motionCalibrationRepository = makeMotionCalibrationRepository()
        let rideTripRepository = makeRideTripRepository()
        let sessionServices = AppSessionDependencyContainer.makeServices(
            dependencies: .init(
                repository: repository,
                profileRepository: profileRepository,
                settingsRepository: settingsRepository,
                deviceSpeedRepository: deviceSpeedRepository,
                deviceMotionRepository: deviceMotionRepository,
                motionCalibrationRepository: motionCalibrationRepository,
                rideTripRepository: rideTripRepository
            )
        )
        return AppDependencyContainer(
            diagnosticsContainer: BikeDiagnosticsDependencyContainer(),
            batteryHealthContainer: BatteryHealthDependencyContainer(),
            session: session,
            chargeControlSession: chargeControl,
            profileRepository: profileRepository,
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            rideTripRepository: rideTripRepository,
            sessionServices: sessionServices,
            onboardingContainer: BikeOnboardingDependencyContainer(),
            dashboardContainer: RideDashboardDependencyContainer(),
            appSettingsContainer: AppSettingsDependencyContainer(),
            bleTraceLogRepository: bleTraceRepository
        )
    }

    private static func makeRideTripRepository() -> SwiftDataRideTripRepository {
        do {
            return try SwiftDataRideTripRepository(
                mapper: RideTripRecordMapper(),
                energyBucketMapper: RideEnergyBucketRecordMapper()
            )
        } catch {
            preconditionFailure("Unable to create the ride trip store: \(error)")
        }
    }

    private static func makeMotionCalibrationRepository() -> SwiftDataVehicleMotionCalibrationRepository {
        do {
            return try SwiftDataVehicleMotionCalibrationRepository(
                mapper: VehicleMotionCalibrationRecordMapper()
            )
        } catch {
            preconditionFailure("Unable to create the motion calibration store: \(error)")
        }
    }
}
