import Foundation
import SettingsDomain

actor DashboardCardSettingsRepository: AppSettingsRepository {
    private(set) var settings: AppSettings
    private(set) var savedSettings: [AppSettings] = []
    private(set) var saveCallCount = 0
    private var continuations: [UUID: AsyncStream<AppSettings>.Continuation] = [:]
    private var shouldBlockNextSave = false
    private var blockedSaveContinuation: CheckedContinuation<Void, Never>?
    private var blockedSaveWaiters: [CheckedContinuation<Void, Never>] = []

    init(settings: AppSettings = .init()) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }

    func save(_ settings: AppSettings) async {
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
        guard !Task.isCancelled else { return }
        guard settings != self.settings else { return }
        self.settings = settings
        savedSettings.append(settings)
        continuations.values.forEach { $0.yield(settings) }
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

    func observe() -> AsyncStream<AppSettings> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppSettings>.makeStream()
        continuations[id] = continuation
        continuation.yield(settings)
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
