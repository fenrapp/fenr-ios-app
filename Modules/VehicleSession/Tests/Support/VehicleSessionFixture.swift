import BikeDomain
import EnvironmentDomain
import Foundation
import SettingsDomain
import Testing
import TestSupport
@testable import VehicleSession

// The fixture intentionally spells out the complete production dependency graph.
// swiftlint:disable:next function_body_length
func makeVehicleSessionFixture(
    speedSource: SpeedSource = .motorcycle,
    now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) },
    maximumSampleAge: TimeInterval = 5,
    maximumPositionSampleAge: TimeInterval? = nil,
    sleep: @escaping @Sendable (Duration) async throws -> Void = {
        try await Task.sleep(for: $0)
    }
) -> VehicleSessionFixture {
    let repository = VehicleSessionTestRepository()
    let settings = VehicleSessionTestSettingsRepository(speedSource: speedSource)
    let profile = VehicleSessionTestProfileRepository()
    let deviceSpeed = VehicleSessionTestDeviceSpeedRepository()
    let heading = VehicleSessionTestHeadingRepository(hub: TestEventHub(bufferingPolicy: .bufferingNewest(1)))
    let imu = VehicleSessionTestIMURepository()
    let motionCalibration = VehicleSessionTestMotionCalibrationRepository()
    let fixtureDate = now()
    let refreshPowerModeConfiguration = RefreshBikePowerModeConfigurationUseCase(
        repository: repository
    )
    let refreshTractionControlConfiguration = RefreshBikeTractionControlConfigurationUseCase(
        repository: repository
    )
    let observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: repository)
    let startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(
        repository: repository
    )
    let stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(
        repository: repository
    )
    let service = LiveVehicleSessionService(
        useCases: .init(
            observeTelemetry: .init(repository: repository),
            observeConnection: .init(repository: repository),
            observeSettings: .init(repository: settings),
            observeDeviceSpeed: .init(repository: deviceSpeed),
            observeIMU: .init(repository: imu),
            startIMUMonitoring: .init(repository: imu),
            stopIMUMonitoring: .init(repository: imu),
            loadMotionCalibration: .init(repository: motionCalibration),
            saveMotionCalibration: .init(repository: motionCalibration),
            observeBikeProfile: .init(repository: profile),
            observeBatteryHealth: observeBatteryHealth,
            startBatteryHealthMonitoring: startBatteryHealthMonitoring,
            stopBatteryHealthMonitoring: stopBatteryHealthMonitoring,
            readBikeStatusSnapshot: .init(repository: repository),
            refreshPowerModeConfiguration: refreshPowerModeConfiguration,
            refreshTractionControlConfiguration: refreshTractionControlConfiguration,
            observeDeviceHeading: .init(repository: heading)
        ),
        powerModeRefreshCoordinator: .init(
            refreshPowerModeConfiguration: refreshPowerModeConfiguration,
            refreshTractionControlConfiguration: refreshTractionControlConfiguration
        ),
        batteryHealthMonitoringCoordinator: .init(
            observeBatteryHealth: observeBatteryHealth,
            startBatteryHealthMonitoring: startBatteryHealthMonitoring,
            stopBatteryHealthMonitoring: stopBatteryHealthMonitoring
        ),
        speedResolver: .init(
            now: now,
            maximumAccuracyMetersPerSecond: 5,
            maximumSampleAge: maximumSampleAge
        ),
        motionEstimator: .init(
            profile: .init(
                version: 1,
                accelerationTransform: .init(
                    bikeX: .positiveX,
                    bikeY: .positiveY,
                    bikeZ: .positiveZ
                ),
                gyroscopeTransform: .init(
                    bikeX: .positiveX,
                    bikeY: .positiveY,
                    bikeZ: .positiveZ
                ),
                gyroscopeDegreesPerSecondPerRawUnit: .init(x: 0.01, y: 0.01, z: 0.01),
                oneGRaw: 1_000
            ),
            now: now,
            maximumSampleAge: maximumSampleAge,
            attitudeFilter: .init(),
            calibrationTracker: .init(),
            locationResolver: .init(
                now: now,
                maximumSampleAge: maximumSampleAge,
                minimumCourseSpeedKilometersPerHour: 5,
                maximumCourseAccuracyDegrees: 35,
                maximumPositionSampleAge: maximumPositionSampleAge
            )
        ),
        sleep: sleep
    )
    return VehicleSessionFixture(
        service: service,
        repository: repository,
        settings: settings,
        profile: profile,
        deviceSpeed: deviceSpeed,
        heading: heading,
        imu: imu,
        motionCalibration: motionCalibration,
        now: fixtureDate
    )
}

struct VehicleSessionFixture {
    let service: LiveVehicleSessionService
    let repository: VehicleSessionTestRepository
    let settings: VehicleSessionTestSettingsRepository
    let profile: VehicleSessionTestProfileRepository
    let deviceSpeed: VehicleSessionTestDeviceSpeedRepository
    let heading: VehicleSessionTestHeadingRepository
    let imu: VehicleSessionTestIMURepository
    let motionCalibration: VehicleSessionTestMotionCalibrationRepository
    let now: Date

    func latestSnapshot() async -> VehicleSessionSnapshot {
        let stream = await service.observe()
        for await snapshot in stream { return snapshot }
        fatalError("Vehicle session stream finished unexpectedly")
    }
}
