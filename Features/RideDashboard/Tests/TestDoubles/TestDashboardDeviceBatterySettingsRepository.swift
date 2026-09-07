import SettingsDomain
import TestSupport

actor TestDashboardDeviceBatterySettingsRepository: AppSettingsRepository {
    private let hub = TestEventHub<AppSettingsSnapshot>(bufferingPolicy: .unbounded)
    private var settings: AppSettings
    private var revision: UInt64 = 0
    private var blocksNextUpdate = false
    private var updateContinuation: CheckedContinuation<Void, Never>?
    private var shouldFail = false
    private(set) var changes: [AppSettingsChange] = []

    init(settings: AppSettings = .init()) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
    }

    func load() -> AppSettings { settings }

    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        changes.append(change)
        if blocksNextUpdate {
            blocksNextUpdate = false
            await withCheckedContinuation { updateContinuation = $0 }
        }
        try Task.checkCancellation()
        if shouldFail { throw AppSettingsUpdateError.persistenceFailed }
        guard expectedVIN == settings.vin else { throw AppSettingsUpdateError.vehicleChanged }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(.init(settings: settings, revision: revision)) }
        settings = updated
        revision += 1
        let snapshot = AppSettingsSnapshot(settings: settings, revision: revision)
        await hub.send(snapshot)
        return .changed(snapshot)
    }

    func observe() async -> AsyncStream<AppSettingsSnapshot> {
        await hub.stream(replay: .init(settings: settings, revision: revision))
    }

    func send(_ snapshot: AppSettingsSnapshot) async {
        if snapshot.revision > revision {
            settings = snapshot.settings
            revision = snapshot.revision
        }
        await hub.send(snapshot)
    }

    func blockNextUpdate() { blocksNextUpdate = true }
    func hasBlockedUpdate() -> Bool { updateContinuation != nil }
    func resumeUpdate() {
        updateContinuation?.resume()
        updateContinuation = nil
    }
    func setFailsUpdating(_ value: Bool) { shouldFail = value }
}
