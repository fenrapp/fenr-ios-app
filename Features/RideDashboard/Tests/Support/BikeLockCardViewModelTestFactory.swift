import BikeDomain
@testable import RideDashboard
import SettingsDomain

@MainActor
struct BikeLockCardViewModelTestFixture {
    let viewModel: BikeLockCardViewModel
    let repository: BikeLockCardRepository
    let settingsRepository: BikeLockCardSettingsRepository
    let vehicleSession: RideDashboardVehicleSession
    let credentialStore: BikeLockCardCredentialStore
}

@MainActor
enum BikeLockCardViewModelTestFactory {
    static func make(
        isLocked: Bool = false,
        settings: AppSettings = .init(),
        authenticator: BikeLockCardAuthenticator = .init(),
        allowsExperimentalControl: Bool = true
    ) -> BikeLockCardViewModelTestFixture {
        let repository = BikeLockCardRepository(isLocked: isLocked)
        let settingsRepository = BikeLockCardSettingsRepository(settings: settings)
        let vehicleSession = RideDashboardVehicleSession()
        let credentialStore = BikeLockCardCredentialStore()
        return .init(
            viewModel: BikeLockCardViewModel(
                prepareControl: .init(repository: repository),
                setLocked: .init(repository: repository),
                loadSettings: .init(repository: settingsRepository),
                saveSettings: .init(repository: settingsRepository),
                vehicleSession: vehicleSession,
                credentialStore: credentialStore,
                authenticator: authenticator,
                allowsExperimentalControl: allowsExperimentalControl
            ),
            repository: repository,
            settingsRepository: settingsRepository,
            vehicleSession: vehicleSession,
            credentialStore: credentialStore
        )
    }
}
