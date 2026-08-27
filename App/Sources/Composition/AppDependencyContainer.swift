import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeDomain
import BikeOnboarding
import ChargeControl
import EnvironmentDomain
import Foundation
import RideDashboard
import RideSession
import RideSessionDomain
import RuntimeConfiguration
import SettingsDomain
import VehicleSession

struct AppSessionServices {
    let vehicle: any VehicleSessionService
    let ride: any RideSessionService
}

enum AppSessionDependencyContainer {
    static func makeServices(
        dependencies: AppSessionDependencies,
        applicationSessionID: UUID = UUID()
    ) -> AppSessionServices {
        let vehicleSession = VehicleSessionDependencyContainer.makeService(
            dependencies: .init(
                repository: dependencies.repository,
                profileRepository: dependencies.profileRepository,
                settingsRepository: dependencies.settingsRepository,
                deviceSpeedRepository: dependencies.deviceSpeedRepository,
                deviceMotionRepository: dependencies.deviceMotionRepository,
                motionCalibrationRepository: dependencies.motionCalibrationRepository
            )
        )
        let rideSession = RideSessionDependencyContainer.makeService(
            dependencies: .init(
                rideTripRepository: dependencies.rideTripRepository,
                applicationSessionID: applicationSessionID
            ),
            vehicleSession: vehicleSession
        )
        return AppSessionServices(vehicle: vehicleSession, ride: rideSession)
    }
}

struct AppSessionDependencies {
    let repository: any BikeRepository & BikeBatteryHealthRepository
    let profileRepository: any BikeProfileRepository
    let settingsRepository: any AppSettingsRepository
    let deviceSpeedRepository: any DeviceSpeedRepository
    let deviceMotionRepository: any DeviceMotionRepository
    let motionCalibrationRepository: any VehicleMotionCalibrationRepository
    let rideTripRepository: any RideTripRepository
}

@MainActor
struct AppDependencyContainer {
    private let diagnosticsContainer: BikeDiagnosticsDependencyContainer
    private let batteryHealthContainer: BatteryHealthDependencyContainer
    private let onboardingContainer: BikeOnboardingDependencyContainer
    private let dashboardContainer: RideDashboardDependencyContainer
    private let appSettingsContainer: AppSettingsDependencyContainer
    private let session: BikeSession
    private let chargeControlSession: ChargeControlSession
    private let profileRepository: any BikeProfileRepository
    private let settingsRepository: any AppSettingsRepository
    private let deviceSpeedRepository: any DeviceSpeedRepository
    private let rideTripRepository: any RideTripRepository
    private let rideSession: any RideSessionService
    private let vehicleSession: any VehicleSessionService
    private let initialOnboardingVIN: String?
    private let forceOnboarding: Bool

    init(
        diagnosticsContainer: BikeDiagnosticsDependencyContainer,
        batteryHealthContainer: BatteryHealthDependencyContainer,
        session: BikeSession,
        chargeControlSession: ChargeControlSession,
        profileRepository: any BikeProfileRepository,
        settingsRepository: any AppSettingsRepository,
        deviceSpeedRepository: any DeviceSpeedRepository,
        rideTripRepository: any RideTripRepository,
        sessionServices: AppSessionServices,
        onboardingContainer: BikeOnboardingDependencyContainer,
        dashboardContainer: RideDashboardDependencyContainer,
        appSettingsContainer: AppSettingsDependencyContainer,
        initialOnboardingVIN: String? = nil,
        forceOnboarding: Bool = false
    ) {
        self.diagnosticsContainer = diagnosticsContainer
        self.batteryHealthContainer = batteryHealthContainer
        self.onboardingContainer = onboardingContainer
        self.dashboardContainer = dashboardContainer
        self.appSettingsContainer = appSettingsContainer
        self.session = session
        self.chargeControlSession = chargeControlSession
        self.profileRepository = profileRepository
        self.settingsRepository = settingsRepository
        self.deviceSpeedRepository = deviceSpeedRepository
        self.rideTripRepository = rideTripRepository
        vehicleSession = sessionServices.vehicle
        rideSession = sessionServices.ride
        self.initialOnboardingVIN = initialOnboardingVIN
        self.forceOnboarding = forceOnboarding
    }

    func makeRootDependencies() -> AppRootDependencies {
        let setupFlow = BikeSetupFlowController(
            useCases: makeBikeProfileUseCases(),
            forceOnboarding: forceOnboarding
        )
        let sessionController = BikeSessionController(
            useCases: .init(
                startRepository: .init(repository: session.repository),
                stopRepository: .init(repository: session.repository),
                connectToBike: .init(repository: session.repository),
                disconnectFromBike: .init(repository: session.repository)
            )
        )
        let bikeLiveActivityController = makeBikeLiveActivityController()
        let rideDashboardFactory = AppRideDashboardFeatureFactory(
            container: dashboardContainer,
            dependencies: .init(
                rideTripRepository: rideTripRepository,
                chargeControl: chargeControlSession,
                rideSession: rideSession,
                vehicleSession: vehicleSession
            )
        )
        return AppRootDependencies(
            diagnosticsViewModel: makeBikeDiagnosticsViewModel(session: session),
            batteryHealthViewModel: makeBatteryHealthViewModel(session: session),
            rideDashboardFactory: rideDashboardFactory,
            onboardingViewModel: makeOnboardingViewModel { vin in
                setupFlow.complete(vin: vin)
            },
            appSettingsViewModel: makeAppSettingsViewModel(),
            setupFlow: setupFlow,
            lifecycleController: AppLifecycleController(
                sessionController: sessionController,
                setupFlow: setupFlow,
                bikeLiveActivityController: bikeLiveActivityController,
                rideSession: rideSession,
                vehicleSession: vehicleSession
            ),
            interfaceOrientationController: .shared
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
            pinDeriver: session.pinDeriver,
            profileRepository: profileRepository,
            settingsRepository: settingsRepository
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

    func makeBikeLiveActivityController() -> BikeLiveActivityController {
        let activityClient = ActivityKitBikeLiveActivityClient()
        let locale = Locale.autoupdatingCurrent
        return BikeLiveActivityController(
            vehicleSession: vehicleSession,
            activityClient: activityClient,
            clock: SystemBikeLiveActivityClock(),
            updateInterval: FENRRuntimeConstants.LiveActivity.chargingUpdateInterval,
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
