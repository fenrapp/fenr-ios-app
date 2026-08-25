import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeDomain
import BikeOnboarding
import ChargeControl
import EnvironmentDomain
import Foundation
import RideDashboard
import RuntimeConfiguration
import SettingsDomain

@MainActor
struct AppDependencyContainer {
    private let diagnosticsContainer: BikeDiagnosticsDependencyContainer
    private let batteryHealthContainer: BatteryHealthDependencyContainer
    private let onboardingContainer: BikeOnboardingDependencyContainer
    private let dashboardContainer: RideDashboardDependencyContainer
    private let chargingDashboardContainer: ChargingDashboardDependencyContainer
    private let appSettingsContainer: AppSettingsDependencyContainer
    private let session: BikeSession
    private let chargeControlSession: ChargeControlSession
    private let profileRepository: any BikeProfileRepository
    private let settingsRepository: any AppSettingsRepository
    private let deviceSpeedRepository: any DeviceSpeedRepository
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
        onboardingContainer: BikeOnboardingDependencyContainer,
        dashboardContainer: RideDashboardDependencyContainer,
        chargingDashboardContainer: ChargingDashboardDependencyContainer,
        appSettingsContainer: AppSettingsDependencyContainer,
        initialOnboardingVIN: String? = nil,
        forceOnboarding: Bool = false
    ) {
        self.diagnosticsContainer = diagnosticsContainer
        self.batteryHealthContainer = batteryHealthContainer
        self.onboardingContainer = onboardingContainer
        self.dashboardContainer = dashboardContainer
        self.chargingDashboardContainer = chargingDashboardContainer
        self.appSettingsContainer = appSettingsContainer
        self.session = session
        self.chargeControlSession = chargeControlSession
        self.profileRepository = profileRepository
        self.settingsRepository = settingsRepository
        self.deviceSpeedRepository = deviceSpeedRepository
        self.initialOnboardingVIN = initialOnboardingVIN
        self.forceOnboarding = forceOnboarding
    }

    func makeBikeDiagnosticsViewModel() -> BikeDiagnosticsViewModel {
        makeBikeDiagnosticsViewModel(session: session)
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
        let bikeLiveActivityController = makeBikeLiveActivityController(session: session)
        return AppRootDependencies(
            diagnosticsViewModel: makeBikeDiagnosticsViewModel(session: session),
            batteryHealthViewModel: makeBatteryHealthViewModel(session: session),
            dashboardViewModel: makeRideDashboardViewModel(session: session),
            chargingDashboardViewModel: makeChargingDashboardViewModel(session: session),
            onboardingViewModel: makeOnboardingViewModel { vin in
                setupFlow.complete(vin: vin)
            },
            appSettingsViewModel: makeAppSettingsViewModel(),
            setupFlow: setupFlow,
            lifecycleController: AppLifecycleController(
                sessionController: sessionController,
                setupFlow: setupFlow,
                bikeLiveActivityController: bikeLiveActivityController
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
            settingsRepository: settingsRepository,
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

    func makeRideDashboardViewModel(session: BikeSession) -> RideDashboardViewModel {
        dashboardContainer.makeViewModel(
            repository: session.repository,
            settingsRepository: settingsRepository,
            deviceSpeedRepository: deviceSpeedRepository
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

    func makeChargingDashboardViewModel(session: BikeSession) -> ChargingDashboardViewModel {
        chargingDashboardContainer.makeViewModel(
            repository: session.repository,
            settingsRepository: settingsRepository,
            chargeControl: chargeControlSession
        )
    }

    func makeBikeLiveActivityController(session: BikeSession) -> BikeLiveActivityController {
        let activityClient: BikeLiveActivityClient
        let locale = Locale.autoupdatingCurrent
        if #available(iOS 16.1, *) {
            activityClient = ActivityKitBikeLiveActivityClient()
        } else {
            activityClient = NoOpBikeLiveActivityClient()
        }
        return BikeLiveActivityController(
            useCases: .init(
                observeTelemetry: .init(repository: session.repository),
                observeBatteryHealth: .init(repository: session.repository),
                observeConnection: .init(repository: session.repository),
                observeSettings: .init(repository: settingsRepository),
                startBatteryHealthMonitoring: .init(repository: session.repository),
                stopBatteryHealthMonitoring: .init(repository: session.repository)
            ),
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
