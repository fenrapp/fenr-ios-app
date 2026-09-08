import SettingsDomain
import TestSupport

actor PowerModeSettingsRepository: AppSettingsRepository {
    private let hub = TestEventHub<AppSettingsSnapshot>(bufferingPolicy: .unbounded)
    private let operation: ControllablePowerModeSettingsOperation?
    private var revision: UInt64 = 0
    private(set) var settings: AppSettings
    private(set) var changes: [AppSettingsChange] = []

    init(settings: AppSettings = .init(), operation: ControllablePowerModeSettingsOperation? = nil) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
        self.operation = operation
    }

    func load() -> AppSettings { settings }

    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        changes.append(change)
        try await operation?.run()
        try Task.checkCancellation()
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

    func send(_ settings: AppSettings) async {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
        revision += 1
        await hub.send(.init(settings: self.settings, revision: revision))
    }
}
