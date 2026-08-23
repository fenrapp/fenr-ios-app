import AppSettings
import BatteryHealth
import BikeDiagnostics
import BikeDomain
import BikeOnboarding
import EnvironmentDomain
import RideDashboard
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
    private let profileRepository: any BikeProfileRepository
    private let settingsRepository: any AppSettingsRepository
    private let deviceSpeedRepository: any DeviceSpeedRepository
    private let initialOnboardingVIN: String?
    let forceOnboarding: Bool

    init(
        diagnosticsContainer: BikeDiagnosticsDependencyContainer,
        batteryHealthContainer: BatteryHealthDependencyContainer,
        session: BikeSession,
        profileRepository: any BikeProfileRepository,
        settingsRepository: any AppSettingsRepository,
        deviceSpeedRepository: any DeviceSpeedRepository,
        onboardingContainer: BikeOnboardingDependencyContainer = .init(),
        dashboardContainer: RideDashboardDependencyContainer = .init(),
        chargingDashboardContainer: ChargingDashboardDependencyContainer = .init(),
        appSettingsContainer: AppSettingsDependencyContainer = .init(),
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
        self.profileRepository = profileRepository
        self.settingsRepository = settingsRepository
        self.deviceSpeedRepository = deviceSpeedRepository
        self.initialOnboardingVIN = initialOnboardingVIN
        self.forceOnboarding = forceOnboarding
    }

    func makeBikeDiagnosticsViewModel() -> BikeDiagnosticsViewModel {
        makeBikeDiagnosticsViewModel(session: session)
    }

    func makeBikeSession() -> BikeSession {
        session
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
            settingsRepository: settingsRepository
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
            deviceSpeedRepository: deviceSpeedRepository
        )
    }

    func makeChargingDashboardViewModel(session: BikeSession) -> ChargingDashboardViewModel {
        chargingDashboardContainer.makeViewModel(
            repository: session.repository,
            settingsRepository: settingsRepository
        )
    }
}
