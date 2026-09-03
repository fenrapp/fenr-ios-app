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
    let capabilityStore: BikeLockCardCapabilityStore
}

@MainActor
enum BikeLockCardViewModelTestFactory {
    static func make(
        isLocked: Bool = false,
        settings: AppSettings = .init(),
        authenticator: any BikeLockAuthenticating = BikeLockCardAuthenticator(),
        suspendsPreparation: Bool = false,
        allowsExperimentalControl: Bool = true
    ) -> BikeLockCardViewModelTestFixture {
        let repository = BikeLockCardRepository(
            isLocked: isLocked,
            suspendsPreparation: suspendsPreparation
        )
        let settingsRepository = BikeLockCardSettingsRepository(settings: settings)
        let vehicleSession = RideDashboardVehicleSession()
        let credentialStore = BikeLockCardCredentialStore()
        let capabilityStore = BikeLockCardCapabilityStore()
        return .init(
            viewModel: BikeLockCardViewModel(
                operationService: BikeLockCardOperationService(
                    prepareControl: .init(repository: repository),
                    setLocked: .init(repository: repository),
                    updateSecurity: .init(
                        repository: settingsRepository,
                        credentialStore: credentialStore
                    ),
                    credentialStore: credentialStore,
                    authenticator: authenticator
                ),
                vehicleSession: vehicleSession,
                capabilityStore: capabilityStore,
                mapper: BikeLockCardViewStateMapper(),
                vehicleContextMapper: BikeLockCardVehicleContextMapper(),
                securityOptionProvider: BikeLockSecurityOptionProvider(),
                allowsExperimentalControl: allowsExperimentalControl
            ),
            repository: repository,
            settingsRepository: settingsRepository,
            vehicleSession: vehicleSession,
            credentialStore: credentialStore,
            capabilityStore: capabilityStore
        )
    }
}
