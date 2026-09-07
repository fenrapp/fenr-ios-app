import Foundation
import SettingsDomain
import TestSupport

actor StubAppSettingsRepository: AppSettingsRepository {
    private let settingsHub = TestEventHub<AppSettingsSnapshot>(bufferingPolicy: .bufferingNewest(1))
    private var settings: AppSettings
    private var saves: [AppSettings] = []
    private var saveInvocations = 0
    private var revision: UInt64 = 0
    private var nextUpdateError: AppSettingsUpdateError?
    private var shouldSuspendNextSave = false
    private var suspendedSaveContinuation: CheckedContinuation<Void, Never>?
    private var saveSuspendedWaiters: [CheckedContinuation<Void, Never>] = []
    private var loadContinuations: [CheckedContinuation<AppSettings, Never>] = []
    private var blocksLoads = false

    init(settings: AppSettings = .init()) {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
    }

    func load() async -> AppSettings {
        if blocksLoads {
            return await withCheckedContinuation { continuation in
                loadContinuations.append(continuation)
            }
        }
        return settings
    }

    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
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
        try Task.checkCancellation()
        guard settings.vin == expectedVIN else { throw AppSettingsUpdateError.vehicleChanged }
        if let error = nextUpdateError {
            nextUpdateError = nil
            throw error
        }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(snapshot) }
        settings = updated
        saves.append(updated)
        revision += 1
        await settingsHub.send(snapshot)
        return .changed(snapshot)
    }

    func observe() async -> AsyncStream<AppSettingsSnapshot> {
        await settingsHub.stream(replay: snapshot)
    }

    func publish(_ settings: AppSettings) async {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
        revision += 1
        await settingsHub.send(snapshot)
    }

    var snapshot: AppSettingsSnapshot { .init(settings: settings, revision: revision) }

    func publishSnapshot(_ snapshot: AppSettingsSnapshot) async { await settingsHub.send(snapshot) }
    func failNextUpdate(_ error: AppSettingsUpdateError) { nextUpdateError = error }

    func waitForSubscriber() async -> Bool {
        await settingsHub.waitForSubscriber()
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
