import SettingsDomain

enum SettingsDomainRecordedOperation: Equatable, Sendable {
    case credentialSaved(vehicleIdentifier: String)
    case credentialRemoved(vehicleIdentifier: String)
    case settingsSaved
}

actor SettingsDomainOperationRecorder {
    private var recordedOperations: [SettingsDomainRecordedOperation] = []

    func record(_ operation: SettingsDomainRecordedOperation) {
        recordedOperations.append(operation)
    }

    func operations() -> [SettingsDomainRecordedOperation] {
        recordedOperations
    }
}

actor RecordingAppSettingsRepository: AppSettingsRepository {
    private var settings: AppSettings
    private var savedSettings: [AppSettings] = []
    private let operationRecorder: SettingsDomainOperationRecorder?
    private let updateError: AppSettingsUpdateError?
    private var revision: UInt64 = 0

    init(
        settings: AppSettings = .init(),
        operationRecorder: SettingsDomainOperationRecorder? = nil,
        updateError: AppSettingsUpdateError? = nil
    ) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
        self.operationRecorder = operationRecorder
        self.updateError = updateError
    }

    func load() async -> AppSettings {
        settings
    }

    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        guard expectedVIN == settings.vin else { throw AppSettingsUpdateError.vehicleChanged }
        if let updateError { throw updateError }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(.init(settings: settings, revision: revision)) }
        settings = updated
        revision += 1
        savedSettings.append(updated)
        await operationRecorder?.record(.settingsSaved)
        return .changed(.init(settings: settings, revision: revision))
    }

    func observe() async -> AsyncStream<AppSettingsSnapshot> {
        let snapshot = AppSettingsSnapshot(settings: settings, revision: revision)
        return AsyncStream { continuation in
            continuation.yield(snapshot)
            continuation.finish()
        }
    }

    func saves() -> [AppSettings] {
        savedSettings
    }

    func currentSettings() -> AppSettings {
        settings
    }

    func switchVIN(_ vin: String) {
        settings = AppSettings().scoped(toVIN: vin)
        revision += 1
    }
}
