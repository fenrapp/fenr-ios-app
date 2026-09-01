import BLETraceDomain
import RideDashboard
import RuntimeConfiguration

@MainActor
final class AppLifecycleControllerFixture {
    let repository: SessionSpyRepository
    let vehicleSession = LifecycleVehicleSessionSpy()
    let rideSession = LifecycleRideSessionSpy()
    let startupPreparer: ControllableAppStartupPreparer
    let lifecycleController: AppLifecycleController

    init(
        bleTraceStoragePreparer: any BLETraceStoragePreparing = NoOpBLETraceRepository(),
        startupPreparer: ControllableAppStartupPreparer = .init()
    ) {
        repository = SessionSpyRepository()
        self.startupPreparer = startupPreparer
        let profileRepository = SetupProfileRepository(
            profile: .init(vin: "FENRTEST000000001")
        )
        let setupFlow = BikeSetupFlowController(
            useCases: .init(
                load: .init(repository: profileRepository),
                clear: .init(repository: profileRepository)
            ),
            forceOnboarding: false
        )
        let sessionController = BikeSessionController(
            useCases: .init(
                startRepository: .init(repository: repository),
                stopRepository: .init(repository: repository),
                connectToBike: .init(repository: repository),
                disconnectFromBike: .init(repository: repository)
            )
        )
        let liveActivityController = BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: FakeBikeLiveActivityClient(),
            clock: FakeBikeLiveActivityClock(),
            updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval,
            stateMapper: BikeLiveActivityStateMapper(
                makeDashboardMapper: { settings in
                    RideDashboardMapperFactory.makeChargingMapper(
                        settings: settings,
                        locale: .init(identifier: "en_US")
                    )
                },
                makeSpeedMapper: { measurementSystem in
                    RideDashboardMapperFactory.makeMeasurementMapper(
                        measurementSystem: measurementSystem,
                        locale: .init(identifier: "en_US")
                    )
                },
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval,
                completeBatteryPercent: FENRRuntimeConstants.LiveActivity.completeBatteryPercent
            )
        )
        lifecycleController = AppLifecycleController(
            sessionController: sessionController,
            setupFlow: setupFlow,
            bikeLiveActivityController: liveActivityController,
            rideSession: rideSession,
            vehicleSession: vehicleSession,
            bleTraceStoragePreparer: bleTraceStoragePreparer,
            startupPreparer: startupPreparer
        )
    }
}
