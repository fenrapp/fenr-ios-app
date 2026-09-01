import SettingsDomain

actor StubAppSettingsRepository: AppSettingsRepository {
    private var settings: AppSettings
    private var saves: [AppSettings] = []
    private var saveInvocations = 0
    private var shouldSuspendNextSave = false
    private var suspendedSaveContinuation: CheckedContinuation<Void, Never>?
    private var saveSuspendedWaiters: [CheckedContinuation<Void, Never>] = []
    private var loadContinuations: [CheckedContinuation<AppSettings, Never>] = []
    private var blocksLoads = false

    init(settings: AppSettings = .init()) {
        self.settings = settings
    }

    func load() async -> AppSettings {
        if blocksLoads {
            return await withCheckedContinuation { continuation in
                loadContinuations.append(continuation)
            }
        }
        return settings
    }

    func save(_ settings: AppSettings) async {
        saveInvocations += 1
        if shouldSuspendNextSave {
            shouldSuspendNextSave = false
            await withCheckedContinuation { continuation in
                suspendedSaveContinuation = continuation
                let waiters = saveSuspendedWaiters
                saveSuspendedWaiters.removeAll()
                waiters.forEach { $0.resume() }
            }
        }
        self.settings = settings
        saves.append(settings)
    }

    func observe() -> AsyncStream<AppSettings> {
        AsyncStream { continuation in
            continuation.yield(settings)
            continuation.finish()
        }
    }

    func suspendNextSave() {
        precondition(!shouldSuspendNextSave)
        precondition(suspendedSaveContinuation == nil)
        shouldSuspendNextSave = true
    }

    func waitUntilSaveIsSuspended() async {
        guard suspendedSaveContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            saveSuspendedWaiters.append(continuation)
        }
    }

    func resumeSuspendedSave() {
        guard let continuation = suspendedSaveContinuation else { return }
        suspendedSaveContinuation = nil
        continuation.resume()
    }

    func saveInvocationCount() -> Int {
        saveInvocations
    }

    func savedSettings() -> [AppSettings] {
        saves
    }

    func blockLoads() {
        blocksLoads = true
    }

    var pendingLoadCount: Int {
        loadContinuations.count
    }

    func resumeLoads(with settings: AppSettings) {
        blocksLoads = false
        let continuations = loadContinuations
        loadContinuations.removeAll()
        continuations.forEach { $0.resume(returning: settings) }
    }
}
