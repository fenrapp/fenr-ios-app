import EnvironmentDomain
import Foundation
import SettingsDomain
import TestSupport

actor SettingsRepository: AppSettingsRepository, DeviceSpeedRepository {
    private let settingsHub = TestEventHub<AppSettingsSnapshot>(bufferingPolicy: .bufferingNewest(1))
    private(set) var settings = AppSettings().scoped(toVIN: "FENRTEST000000001")
    private var revision: UInt64 = 0
    private var nextUpdateError: AppSettingsUpdateError?
    private var blocksUpdates = false
    private var updateContinuation: CheckedContinuation<Void, Never>?

    var isUpdateBlocked: Bool { updateContinuation != nil }

    func load() -> AppSettings { settings }
    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        if blocksUpdates {
            blocksUpdates = false
            await withCheckedContinuation { updateContinuation = $0 }
        }
        try Task.checkCancellation()
        guard settings.vin == expectedVIN else { throw AppSettingsUpdateError.vehicleChanged }
        if let error = nextUpdateError {
            nextUpdateError = nil
            throw error
        }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(snapshot) }
        await publish(updated)
        return .changed(snapshot)
    }

    func save(_ settings: AppSettings) async { await publish(settings) }

    func publish(_ settings: AppSettings) async {
        self.settings = settings.scoped(toVIN: settings.vin ?? "FENRTEST000000001")
        revision += 1
        await settingsHub.send(snapshot)
    }

    func publishSnapshot(_ snapshot: AppSettingsSnapshot) async {
        await settingsHub.send(snapshot)
    }

    func failNextUpdate(_ error: AppSettingsUpdateError) { nextUpdateError = error }
    func blockNextUpdate() { blocksUpdates = true }
    func resumeUpdate() { updateContinuation?.resume(); updateContinuation = nil }

    var snapshot: AppSettingsSnapshot { .init(settings: settings, revision: revision) }

    func observe() async -> AsyncStream<AppSettingsSnapshot> {
        await settingsHub.stream(replay: snapshot)
    }
    func observeDeviceSpeed() -> AsyncStream<DeviceSpeedSample> { .init { $0.finish() } }
    func locationAuthorizationStatus() -> LocationAuthorizationStatus { .authorized }
    func requestLocationAuthorization() {}

    func waitForSettingsSubscriber() async -> Bool {
        await settingsHub.waitForSubscriber()
    }
}
