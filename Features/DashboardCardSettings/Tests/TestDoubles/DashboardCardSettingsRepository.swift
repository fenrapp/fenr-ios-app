import Foundation
import SettingsDomain

actor DashboardCardSettingsRepository: AppSettingsRepository {
    private(set) var settings: AppSettings
    private(set) var savedSettings: [AppSettings] = []
    private(set) var saveCallCount = 0
    private var continuations: [UUID: AsyncStream<AppSettingsSnapshot>.Continuation] = [:]
    private var revision: UInt64 = 0
    private var nextUpdateError: AppSettingsUpdateError?
    private var shouldBlockNextSave = false
    private var blockedSaveContinuation: CheckedContinuation<Void, Never>?
    private var blockedSaveWaiters: [CheckedContinuation<Void, Never>] = []

    init(settings: AppSettings = .init()) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
    }

    func load() -> AppSettings { settings }

    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        saveCallCount += 1
        if shouldBlockNextSave {
            shouldBlockNextSave = false
            await withCheckedContinuation { continuation in
                blockedSaveContinuation = continuation
                let waiters = blockedSaveWaiters
                blockedSaveWaiters.removeAll()
                waiters.forEach { $0.resume() }
            }
        }
        try Task.checkCancellation()
        guard settings.vin == expectedVIN else { throw AppSettingsUpdateError.vehicleChanged }
        if let error = nextUpdateError {
            nextUpdateError = nil
            throw error
        }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(snapshot) }
        settings = updated
        savedSettings.append(updated)
        revision += 1
        continuations.values.forEach { $0.yield(snapshot) }
        return .changed(snapshot)
    }

    func blockNextSave() {
        precondition(!shouldBlockNextSave && blockedSaveContinuation == nil)
        shouldBlockNextSave = true
    }

    func waitForBlockedSave() async {
        guard blockedSaveContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            blockedSaveWaiters.append(continuation)
        }
    }

    func releaseBlockedSave() {
        let continuation = blockedSaveContinuation
        blockedSaveContinuation = nil
        continuation?.resume()
    }

    func save(_ settings: AppSettings) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
        revision += 1
        continuations.values.forEach { $0.yield(snapshot) }
    }

    func failNextUpdate(_ error: AppSettingsUpdateError) { nextUpdateError = error }

    var snapshot: AppSettingsSnapshot { .init(settings: settings, revision: revision) }

    func publishSnapshot(_ snapshot: AppSettingsSnapshot) {
        continuations.values.forEach { $0.yield(snapshot) }
    }

    func observe() -> AsyncStream<AppSettingsSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppSettingsSnapshot>.makeStream()
        continuations[id] = continuation
        continuation.yield(snapshot)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    var observerCount: Int {
        continuations.count
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
