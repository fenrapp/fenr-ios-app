import SettingsDomain
import Testing

@Suite("Update Bike Lock security")
struct UpdateBikeLockSecurityUseCaseTests {
    private let vehicleIdentifier = "FENRTEST000000001"
    private let validPIN = "123456"

    @Test("Rejects invalid PINs without touching credentials or settings", arguments: [
        "",
        "12345",
        "1234567",
        "12345A",
        "\u{FF11}\u{FF12}\u{FF13}\u{FF14}\u{FF15}\u{FF16}"
    ])
    func invalidPINDoesNotMutateState(invalidPIN: String) async {
        let repository = RecordingAppSettingsRepository()
        let credentialStore = RecordingBikeLockCredentialStore()
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

        await #expect(throws: BikeLockSecurityUpdateError.invalidPIN) {
            try await useCase.execute(
                vehicleIdentifier: vehicleIdentifier,
                securityMode: .pin,
                newPIN: invalidPIN
            )
        }

        #expect((await credentialStore.saves()).isEmpty)
        #expect((await credentialStore.removals()).isEmpty)
        #expect((await repository.saves()).isEmpty)
    }

    @Test("Does not save settings when credential persistence fails")
    func credentialFailureDoesNotSaveSettings() async {
        let repository = RecordingAppSettingsRepository()
        let credentialStore = RecordingBikeLockCredentialStore(failsSavingPIN: true)
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

        await #expect(throws: RecordingBikeLockCredentialStoreError.self) {
            try await useCase.execute(
                vehicleIdentifier: vehicleIdentifier,
                securityMode: .pin,
                newPIN: validPIN
            )
        }

        #expect((await repository.saves()).isEmpty)
    }

    @Test("Persists a valid six-digit ASCII PIN before its preference")
    func validPINPersistsCredentialAndPreference() async throws {
        let operationRecorder = SettingsDomainOperationRecorder()
        let repository = RecordingAppSettingsRepository(operationRecorder: operationRecorder)
        let credentialStore = RecordingBikeLockCredentialStore(operationRecorder: operationRecorder)
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

        try await useCase.execute(
            vehicleIdentifier: vehicleIdentifier,
            securityMode: .pin,
            newPIN: validPIN
        )

        #expect(await credentialStore.pin(for: vehicleIdentifier) == validPIN)
        #expect(
            await repository.currentSettings().bikeLockSettings(forVIN: vehicleIdentifier).securityMode
                == .pin
        )
        #expect(await operationRecorder.operations() == [
            .credentialSaved(vehicleIdentifier: vehicleIdentifier),
            .settingsSaved
        ])
    }

    @Test("Makes the Bike Lock section visible for a PIN mode")
    func pinModeMakesBikeLockVisible() async throws {
        var settings = AppSettings()
        settings.dashboardCardConfiguration.setSectionVisibility(false, id: .bikeLock)
        let repository = RecordingAppSettingsRepository(settings: settings)
        let credentialStore = RecordingBikeLockCredentialStore()
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

        try await useCase.execute(
            vehicleIdentifier: vehicleIdentifier,
            securityMode: .pinAndFaceID,
            newPIN: validPIN
        )

        #expect(await repository.currentSettings().dashboardCardConfiguration.section(id: .bikeLock).isVisible)
    }

    @Test("Preserves the credential when switching between PIN modes without a new PIN")
    func pinModeChangePreservesCredential() async throws {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: vehicleIdentifier)
        let repository = RecordingAppSettingsRepository(settings: settings)
        let credentialStore = RecordingBikeLockCredentialStore(
            pinsByVehicleIdentifier: [vehicleIdentifier: validPIN]
        )
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

        try await useCase.execute(
            vehicleIdentifier: vehicleIdentifier,
            securityMode: .pinAndFaceID
        )

        #expect(await credentialStore.pin(for: vehicleIdentifier) == validPIN)
        #expect((await credentialStore.saves()).isEmpty)
        #expect((await credentialStore.removals()).isEmpty)
        #expect(
            await repository.currentSettings().bikeLockSettings(forVIN: vehicleIdentifier).securityMode
                == .pinAndFaceID
        )
    }

    @Test("Removes a credential before persisting every mode without PIN")
    func modesWithoutPINRemoveCredentialBeforeSettings() async throws {
        for securityMode in [BikeLockSecurityMode.withoutPIN, .notConfigured] {
            let operationRecorder = SettingsDomainOperationRecorder()
            var settings = AppSettings()
            settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: vehicleIdentifier)
            let repository = RecordingAppSettingsRepository(
                settings: settings,
                operationRecorder: operationRecorder
            )
            let credentialStore = RecordingBikeLockCredentialStore(
                pinsByVehicleIdentifier: [vehicleIdentifier: validPIN],
                operationRecorder: operationRecorder
            )
            let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

            try await useCase.execute(
                vehicleIdentifier: vehicleIdentifier,
                securityMode: securityMode
            )

            #expect(await operationRecorder.operations() == [
                .credentialRemoved(vehicleIdentifier: vehicleIdentifier),
                .settingsSaved
            ])
        }
    }

    @Test("Removes the vehicle preference when security is not configured")
    func notConfiguredRemovesVehiclePreference() async throws {
        var settings = AppSettings()
        settings.setBikeLockSettings(.init(securityMode: .pin), forVIN: vehicleIdentifier)
        let repository = RecordingAppSettingsRepository(settings: settings)
        let credentialStore = RecordingBikeLockCredentialStore(
            pinsByVehicleIdentifier: [vehicleIdentifier: validPIN]
        )
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)

        try await useCase.execute(
            vehicleIdentifier: vehicleIdentifier,
            securityMode: .notConfigured
        )

        #expect(await repository.currentSettings().bikeLockSettingsByVIN[vehicleIdentifier] == nil)
    }

    private func makeUseCase(
        repository: RecordingAppSettingsRepository,
        credentialStore: RecordingBikeLockCredentialStore
    ) -> UpdateBikeLockSecurityUseCase {
        .init(repository: repository, credentialStore: credentialStore)
    }
}
