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

    @Test("Rejects another vehicle before mutating credentials")
    func rejectsMismatchedIdentity() async {
        let repository = RecordingAppSettingsRepository()
        let credentialStore = RecordingBikeLockCredentialStore()
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)
        await #expect(throws: AppSettingsUpdateError.vehicleChanged) {
            try await useCase.execute(vehicleIdentifier: "FENRTEST000000002", securityMode: .pin, newPIN: validPIN)
        }
        #expect(await credentialStore.saves().isEmpty)
        #expect(await repository.saves().isEmpty)
    }

    @Test("Reports settings failure after credential persistence instead of claiming success")
    func propagatesSettingsFailure() async {
        let repository = RecordingAppSettingsRepository(updateError: .unreadableStore)
        let credentialStore = RecordingBikeLockCredentialStore()
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)
        await #expect(throws: AppSettingsUpdateError.unreadableStore) {
            try await useCase.execute(vehicleIdentifier: vehicleIdentifier, securityMode: .pin, newPIN: validPIN)
        }
        #expect(await credentialStore.containsPIN(for: vehicleIdentifier))
        #expect(await repository.saves().isEmpty)
        let settings = await repository.currentSettings()
        #expect(settings.bikeLockSettings(forVIN: vehicleIdentifier).securityMode == .notConfigured)
    }

    @Test("A vehicle switch during credential persistence cannot configure the new vehicle")
    func rejectsIdentityChangeDuringCredentialSave() async {
        let repository = RecordingAppSettingsRepository()
        let credentialStore = RecordingBikeLockCredentialStore(afterSave: {
            await repository.switchVIN("FENRTEST000000002")
        })
        let useCase = makeUseCase(repository: repository, credentialStore: credentialStore)
        await #expect(throws: AppSettingsUpdateError.vehicleChanged) {
            try await useCase.execute(vehicleIdentifier: vehicleIdentifier, securityMode: .pin, newPIN: validPIN)
        }
        #expect(await credentialStore.containsPIN(for: vehicleIdentifier))
        #expect(await repository.saves().isEmpty)
        #expect(await repository.currentSettings().vin == "FENRTEST000000002")
        #expect(await repository.currentSettings().bikeLockSettingsByVIN.isEmpty)
    }

    private func makeUseCase(
        repository: RecordingAppSettingsRepository,
        credentialStore: RecordingBikeLockCredentialStore
    ) -> UpdateBikeLockSecurityUseCase {
        .init(repository: repository, credentialStore: credentialStore)
    }
}
