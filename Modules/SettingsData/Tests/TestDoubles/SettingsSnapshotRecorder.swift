import SettingsDomain

@MainActor
final class SettingsSnapshotRecorder {
    private(set) var values: [AppSettings] = []
    func append(_ value: AppSettings) { values.append(value) }
}
