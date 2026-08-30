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

    init(
        settings: AppSettings = .init(),
        operationRecorder: SettingsDomainOperationRecorder? = nil
    ) {
        self.settings = settings
        self.operationRecorder = operationRecorder
    }

    func load() async -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) async {
        self.settings = settings
        savedSettings.append(settings)
        await operationRecorder?.record(.settingsSaved)
    }

    func observe() async -> AsyncStream<AppSettings> {
        let settings = self.settings
        return AsyncStream { continuation in
            continuation.yield(settings)
            continuation.finish()
        }
    }

    func saves() -> [AppSettings] {
        savedSettings
    }

    func currentSettings() -> AppSettings {
        settings
    }
}
