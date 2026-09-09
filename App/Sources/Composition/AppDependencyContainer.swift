import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeDomain
import BikeLockSettings
import BikeOnboarding
import BLETraceDomain
import ChargeControl
import DashboardCardSettings
import EnvironmentDomain
import Foundation
import MaintenanceDomain
import MaintenanceLog
import PowerModeSettings
import RideDashboard
import RideHistory
import RideNavigation
import RideNavigationDomain
import RideSession
import RideSessionDomain
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

@MainActor
struct AppDependencyContainer {
    private let diagnosticsContainer: BikeDiagnosticsDependencyContainer
    private let batteryHealthContainer: BatteryHealthDependencyContainer
    private let onboardingContainer: BikeOnboardingDependencyContainer
    private let dashboardContainer: RideDashboardDependencyContainer
    private let appSettingsContainer: AppSettingsDependencyContainer
    private let dashboardCardSettingsContainer: DashboardCardSettingsDependencyContainer
    private let powerModeSettingsContainer: PowerModeSettingsDependencyContainer
    private let rideHistoryContainer: RideHistoryDependencyContainer
    private let maintenanceContainer: MaintenanceDependencyContainer
    private let session: BikeSession
    private let chargeControlSession: ChargeControlSession
    private let profileRepository: any BikeProfileRepository
    private let settingsRepository: any AppSettingsRepository
    private let deviceSpeedRepository: any DeviceSpeedRepository
    private let rideTripRepository: any RideTripRepository
    private let maintenanceRepository: any MaintenanceRepository
    private let rideSession: any RideSessionService
    private let vehicleSession: any VehicleSessionService
    private let initialOnboardingVIN: String?
    private let forceOnboarding: Bool
    private let bleTraceLogRepository: any BLETraceLogRepository
    private let incomingMapLinkStore: any IncomingMapLinkStoring
    private let bikeLockCredentialStore: any BikeLockCredentialStoring
    private let bikeLockAuthenticator: any BikeLockAuthenticating
    private let bikeLockCapabilityStore: any BikeLockCapabilityStateStoring
    private let startupPreparer: any AppStartupPreparing
    private let experienceOptions: AppExperienceOptions

    init(
        diagnosticsContainer: BikeDiagnosticsDependencyContainer,
        batteryHealthContainer: BatteryHealthDependencyContainer,
        session: BikeSession,
        chargeControlSession: ChargeControlSession,
        profileRepository: any BikeProfileRepository,
        settingsRepository: any AppSettingsRepository,
        deviceSpeedRepository: any DeviceSpeedRepository,
        rideTripRepository: any RideTripRepository,
        maintenanceRepository: any MaintenanceRepository,
        sessionServices: AppSessionServices,
        onboardingContainer: BikeOnboardingDependencyContainer,
        dashboardContainer: RideDashboardDependencyContainer,
        appSettingsContainer: AppSettingsDependencyContainer,
        dashboardCardSettingsContainer: DashboardCardSettingsDependencyContainer,
        powerModeSettingsContainer: PowerModeSettingsDependencyContainer,
        rideHistoryContainer: RideHistoryDependencyContainer,
        maintenanceContainer: MaintenanceDependencyContainer,
        bleTraceLogRepository: any BLETraceLogRepository,
        incomingMapLinkStore: any IncomingMapLinkStoring,
        bikeLockCredentialStore: any BikeLockCredentialStoring,
        bikeLockAuthenticator: any BikeLockAuthenticating,
        bikeLockCapabilityStore: any BikeLockCapabilityStateStoring,
        startupPreparer: any AppStartupPreparing,
        initialOnboardingVIN: String? = nil,
        forceOnboarding: Bool = false,
        experienceOptions: AppExperienceOptions = .init()
    ) {
        self.diagnosticsContainer = diagnosticsContainer
        self.batteryHealthContainer = batteryHealthContainer
        self.onboardingContainer = onboardingContainer
        self.dashboardContainer = dashboardContainer
        self.appSettingsContainer = appSettingsContainer
        self.dashboardCardSettingsContainer = dashboardCardSettingsContainer
        self.powerModeSettingsContainer = powerModeSettingsContainer
        self.rideHistoryContainer = rideHistoryContainer
        self.maintenanceContainer = maintenanceContainer
        self.session = session
        self.chargeControlSession = chargeControlSession
        self.profileRepository = profileRepository
        self.settingsRepository = settingsRepository
        self.deviceSpeedRepository = deviceSpeedRepository
        self.rideTripRepository = rideTripRepository
        self.maintenanceRepository = maintenanceRepository
        vehicleSession = sessionServices.vehicle
        rideSession = sessionServices.ride
        self.initialOnboardingVIN = initialOnboardingVIN
        self.forceOnboarding = forceOnboarding
        self.bleTraceLogRepository = bleTraceLogRepository
        self.incomingMapLinkStore = incomingMapLinkStore
        self.bikeLockCredentialStore = bikeLockCredentialStore
        self.bikeLockAuthenticator = bikeLockAuthenticator
        self.bikeLockCapabilityStore = bikeLockCapabilityStore
        self.startupPreparer = startupPreparer
        self.experienceOptions = experienceOptions
    }

    func makeRootDependencies(opensRideNavigationOnLaunch: Bool = false) -> AppRootDependencies {
        let setupFlow = BikeSetupFlowController(
            useCases: makeBikeProfileUseCases(),
            forceOnboarding: forceOnboarding
        )
        let onboardingViewModel = makeOnboardingViewModel { vin in
            setupFlow.complete(vin: vin)
        }
        let navigationCoordinator = AppNavigationCoordinator(
            opensRideNavigationOnLaunch: opensRideNavigationOnLaunch
        )
        let externalNavigationResolver = AppExternalNavigationResolver()
        let sessionController = makeSessionController()
        let bikeLiveActivityController = makeBikeLiveActivityController()
        let rideDashboardFactory = AppRideDashboardFeatureFactory(
            container: dashboardContainer,
            dependencies: .init(
                bikeRepository: session.repository,
                rideTripRepository: rideTripRepository,
                chargeControl: chargeControlSession,
                rideSession: rideSession,
                settingsRepository: settingsRepository,
                vehicleSession: vehicleSession,
                bikeLockCredentialStore: bikeLockCredentialStore,
                bikeLockAuthenticator: bikeLockAuthenticator,
                bikeLockCapabilityStore: bikeLockCapabilityStore
            )
        )
        let featureStore = makeFeatureStore(
            onboardingViewModel: onboardingViewModel,
            rideDashboardFactory: rideDashboardFactory
        )
        return AppRootDependencies(
            featureStore: featureStore,
            setupFlow: setupFlow,
            navigationCoordinator: navigationCoordinator,
            incomingMapLinkController: IncomingMapLinkController(
                store: incomingMapLinkStore,
                resolver: externalNavigationResolver,
                onRequest: { [weak navigationCoordinator] request in
                    navigationCoordinator?.open(request)
                }
            ),
            chargeControlSession: chargeControlSession,
            externalNavigationResolver: externalNavigationResolver,
            presentationController: AppPresentationController(
                policy: AppPresentationPolicy(),
                orientationController: InterfaceOrientationController.shared
            ),
            lifecycleController: makeLifecycleController(
                setupFlow: setupFlow,
                sessionController: sessionController,
                bikeLiveActivityController: bikeLiveActivityController
            )
        )
    }

    func makeBikeLockSettingsViewModel() -> BikeLockSettingsViewModel {
        BikeLockSettingsViewModel(
            vehicleSession: vehicleSession,
            capabilityStore: bikeLockCapabilityStore,
            securityService: BikeLockSettingsSecurityService(
                credentialStore: bikeLockCredentialStore,
                authenticator: bikeLockAuthenticator,
                updateSecurity: UpdateBikeLockSecurityUseCase(
                    repository: settingsRepository,
                    credentialStore: bikeLockCredentialStore
                )
            ),
            mapper: BikeLockSettingsViewStateMapper()
        )
    }

    func makeBikeProfileUseCases() -> BikeProfileUseCases {
        BikeProfileUseCases(
            load: LoadBikeProfileUseCase(repository: profileRepository),
            clear: ClearBikeProfileUseCase(repository: profileRepository)
        )
    }

    func makeBikeDiagnosticsViewModel(session: BikeSession) -> BikeDiagnosticsViewModel {
        diagnosticsContainer.makeBikeDiagnosticsViewModel(
            repository: session.repository,
            vehicleSession: vehicleSession,
            bleTraceLogRepository: bleTraceLogRepository
        )
    }

    func makeBatteryHealthViewModel(session: BikeSession) -> BatteryHealthViewModel {
        batteryHealthContainer.makeBatteryHealthViewModel(
            repository: session.repository,
            vehicleSession: vehicleSession,
            chargeControl: chargeControlSession
        )
    }

    func makeOnboardingViewModel(onCompleted: @escaping @MainActor (String) -> Void) -> BikeOnboardingViewModel {
        onboardingContainer.makeViewModel(
            repository: session.repository,
            pinDeriver: session.pinDeriver,
            profileRepository: profileRepository,
            initialVIN: initialOnboardingVIN,
            onCompleted: onCompleted
        )
    }

    func makeAppSettingsViewModel() -> AppSettingsViewModel {
        appSettingsContainer.makeViewModel(
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository,
            bikeRepository: session.repository,
            profileRepository: profileRepository
        )
    }

    func makeDashboardCardSettingsViewModel() -> DashboardCardSettingsViewModel {
        dashboardCardSettingsContainer.makeViewModel(
            settingsRepository: settingsRepository,
            bikeLockCapabilityStore: bikeLockCapabilityStore
        )
    }

    func makePowerModesFeature() -> PowerModeFeature {
        powerModeSettingsContainer.makeFeature(
            settingsRepository: settingsRepository,
            bikeRepository: session.repository,
            vehicleSession: vehicleSession
        )
    }

    func makeRideHistoryViewModel() -> RideHistoryViewModel {
        rideHistoryContainer.makeViewModel(
            repository: rideTripRepository,
            session: rideSession
        )
    }

    func makeMaintenanceViewModel() -> MaintenanceViewModel {
        maintenanceContainer.makeViewModel(
            repository: maintenanceRepository,
            vehicleSession: vehicleSession
        )
    }

    func makeBikeLiveActivityController() -> BikeLiveActivityController {
        let activityClient = ActivityKitBikeLiveActivityClient(isDemo: experienceOptions.isDemo)
        let locale = Locale.autoupdatingCurrent
        return BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: activityClient,
            clock: SystemBikeLiveActivityClock(),
            timing: .live,
            continuityPolicy: RideDashboardContinuityPolicy(),
            updatePolicy: BikeLiveActivityUpdatePolicy(
                updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval
            ),
            reconnectionNoticeDelay: FENRRuntimeConstants.RideDashboard.reconnectionNoticeDelay,
            stateMapper: BikeLiveActivityStateMapper(
                makeDashboardMapper: { settings in
                    RideDashboardMapperFactory.makeChargingMapper(
                        settings: settings,
                        locale: locale
                    )
                },
                makeSpeedMapper: { measurementSystem in
                    RideDashboardMapperFactory.makeMeasurementMapper(
                        measurementSystem: measurementSystem,
                        locale: locale
                    )
                },
                telemetryFreshnessInterval: FENRRuntimeConstants.Telemetry.freshnessInterval,
                completeBatteryPercent: FENRRuntimeConstants.LiveActivity.completeBatteryPercent
            )
        )
    }
}

private extension AppDependencyContainer {
    func makeFeatureStore(
        onboardingViewModel: BikeOnboardingViewModel,
        rideDashboardFactory: any RideDashboardFeatureBuilding
    ) -> AppFeatureStore {
        AppFeatureStore(
            diagnosticsViewModel: makeBikeDiagnosticsViewModel(session: session),
            batteryHealthViewModel: makeBatteryHealthViewModel(session: session),
            bikeLockSettingsViewModel: makeBikeLockSettingsViewModel(),
            onboardingViewModel: onboardingViewModel,
            appSettingsViewModel: makeAppSettingsViewModel(),
            dashboardCardSettingsViewModel: makeDashboardCardSettingsViewModel(),
            powerModes: makePowerModesFeature(),
            rideHistoryViewModel: makeRideHistoryViewModel(),
            maintenanceViewModel: makeMaintenanceViewModel(),
            rideDashboardFactory: rideDashboardFactory,
            rideNavigationFactory: AppRideNavigationFeatureFactory(
                vehicleSession: vehicleSession,
                observeDeviceSpeed: ObserveDeviceSpeedUseCase(
                    repository: deviceSpeedRepository, requestsAuthorization: experienceOptions.isDemo
                ),
                settingsRepository: settingsRepository,
                routeDirectory: experienceOptions.routeDirectory,
                isDemo: experienceOptions.isDemo
            )
        )
    }

    func makeLifecycleController(
        setupFlow: BikeSetupFlowController,
        sessionController: BikeSessionController,
        bikeLiveActivityController: BikeLiveActivityController
    ) -> AppLifecycleController {
        AppLifecycleController(
            sessionController: sessionController,
            setupFlow: setupFlow,
            bikeLiveActivityController: bikeLiveActivityController,
            rideSession: rideSession,
            vehicleSession: vehicleSession,
            stopDiagnosticsCapture: { [repository = session.repository] in
                _ = await repository.stopDiagnosticsCapture()
            },
            startupPreparer: startupPreparer
        )
    }

    func makeSessionController() -> BikeSessionController {
        BikeSessionController(
            useCases: .init(
                startRepository: .init(repository: session.repository),
                stopRepository: .init(repository: session.repository),
                connectToBike: .init(repository: session.repository),
                disconnectFromBike: .init(repository: session.repository)
            )
        )
    }
}
