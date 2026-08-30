import BikeDomain
@testable import BikeLockSettings
import SettingsDomain
import Testing
import TestSupport
import VehicleSession

@Suite("Bike Lock settings")
@MainActor
struct BikeLockSettingsViewModelTests {
    private let vin = "FENRTEST000000001"

    @Test("Changes local protection without a vehicle write dependency")
    func changesToNoPIN() async {
        let fixture = make()
        await start(fixture)
        fixture.viewModel.changeProtection()
        #expect(fixture.viewModel.viewState.destination == .chooseProtection)
        fixture.viewModel.select(.withoutPIN)

        #expect(await waitUntil { fixture.viewModel.viewState.currentMode == .withoutPIN })
        #expect((await fixture.repository.load()).bikeLockSettings(forVIN: vin).securityMode == .withoutPIN)
    }

    @Test("Current PIN protects a PIN change")
    func changesPINAfterVerification() async {
        let fixture = make(mode: .pin, pin: "123456")
        await start(fixture)
        fixture.viewModel.changePIN()
        #expect(fixture.viewModel.viewState.destination == .verifyCurrentPIN)
        fixture.viewModel.submitCurrentPIN("654321")
        #expect(await waitUntil { fixture.viewModel.viewState.errorMessage == "Incorrect PIN" })
        fixture.viewModel.submitCurrentPIN("123456")
        #expect(await waitUntil { fixture.viewModel.viewState.destination == .changePIN })
        fixture.viewModel.saveNewPIN("111222", confirmation: "111222")
        #expect(await waitUntil { await fixture.credentials.storedPIN(for: vin) == "111222" })
    }

    @Test("Cancelled Face ID falls back to the current PIN")
    func faceIDFallsBackToPIN() async {
        let fixture = make(mode: .pinAndFaceID, pin: "123456", faceIDResult: false)
        await start(fixture)
        fixture.viewModel.changeProtection()
        #expect(await waitUntil { fixture.viewModel.viewState.destination == .verifyCurrentPIN })
    }

    @Test("An incompatible VCU hides Bike Lock settings")
    func incompatibleBikeIsUnavailable() async {
        let fixture = make(isAvailable: false)
        await start(fixture)
        #expect(!fixture.viewModel.viewState.isAvailable)
    }

    private func make(
        mode: BikeLockSecurityMode = .notConfigured,
        pin: String? = nil,
        faceIDResult: Bool = true,
        isAvailable: Bool = true
    ) -> Fixture {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: mode), forVIN: vin)
        let repository = BikeLockSettingsTestRepository(settings: settings)
        let credentials = BikeLockSettingsTestCredentialStore(vin: vin, pin: pin)
        let session = BikeLockSettingsTestVehicleSession()
        let capability = BikeLockSettingsTestCapabilityStore(
            state: .init(vehicleIdentifier: vin, isAvailable: isAvailable)
        )
        return Fixture(
            viewModel: .init(
                vehicleSession: session,
                capabilityStore: capability,
                credentialStore: credentials,
                authenticator: BikeLockSettingsTestAuthenticator(result: faceIDResult),
                updateSecurity: .init(repository: repository, credentialStore: credentials)
            ),
            session: session,
            repository: repository,
            credentials: credentials,
            settings: settings
        )
    }

    private func start(_ fixture: Fixture) async {
        fixture.viewModel.start()
        await fixture.session.send(.init(
            settings: fixture.settings,
            profile: .init(vin: vin),
            hasReceivedSettings: true,
            hasReceivedProfile: true
        ))
        _ = await waitUntil { fixture.viewModel.viewState.isAvailable }
    }

    private struct Fixture {
        let viewModel: BikeLockSettingsViewModel
        let session: BikeLockSettingsTestVehicleSession
        let repository: BikeLockSettingsTestRepository
        let credentials: BikeLockSettingsTestCredentialStore
        let settings: AppSettings
    }
}
