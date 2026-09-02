import BikeDomain
@testable import BikeLockSettings
import SettingsDomain
import TestSupport
import VehicleSession

@MainActor
struct BikeLockSettingsViewModelFixture {
    static let defaultVIN = "FENRTEST000000001"
    static let alternateVIN = "FENRTEST000000002"

    let vin: String
    let settings: AppSettings
    let session: BikeLockSettingsTestVehicleSession
    let capabilityStore: BikeLockSettingsTestCapabilityStore
    let repository: BikeLockSettingsTestRepository
    let credentialStore: BikeLockSettingsTestCredentialStore
    let authenticator: ControllableBikeLockSettingsAuthenticator
    let viewModel: BikeLockSettingsViewModel

    init(
        mode: BikeLockSecurityMode = .notConfigured,
        pin: String? = nil,
        authenticatorOutcome: ControllableBikeLockSettingsAuthenticator.Outcome = .success(true),
        isAvailable: Bool = true,
        vin: String = Self.defaultVIN
    ) {
        self.vin = vin
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: mode), forVIN: vin)
        self.settings = settings
        session = BikeLockSettingsTestVehicleSession()
        capabilityStore = BikeLockSettingsTestCapabilityStore(
            state: .init(vehicleIdentifier: vin, isAvailable: isAvailable)
        )
        repository = BikeLockSettingsTestRepository(settings: settings)
        credentialStore = BikeLockSettingsTestCredentialStore(vin: vin, pin: pin)
        authenticator = ControllableBikeLockSettingsAuthenticator(outcome: authenticatorOutcome)
        viewModel = BikeLockSettingsViewModel(
            vehicleSession: session,
            capabilityStore: capabilityStore,
            securityService: BikeLockSettingsSecurityService(
                credentialStore: credentialStore,
                authenticator: authenticator,
                updateSecurity: .init(repository: repository, credentialStore: credentialStore)
            ),
            mapper: BikeLockSettingsViewStateMapper()
        )
    }

    func start() async {
        viewModel.start()
        await sendSnapshot(vin: vin, settings: settings)
        _ = await waitUntil { viewModel.viewState.isAvailable }
    }

    func sendSnapshot(
        vin: String?,
        settings: AppSettings? = nil,
        isCanonicalTelemetryAvailable: Bool = true
    ) async {
        await session.send(.init(
            settings: settings ?? self.settings,
            profile: vin.map { .init(vin: $0) },
            hasReceivedSettings: true,
            hasReceivedProfile: true,
            isCanonicalTelemetryAvailable: isCanonicalTelemetryAvailable
        ))
    }
}
