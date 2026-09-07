import BikeDomain
import Foundation
import SettingsDomain
import StarkProtocol

actor VINScopedAppSettingsRepository: AppSettingsRepository {
    private let store: VINAppSettingsStore
    private let profiles: any BikeProfileRepository
    private var observers: [UUID: Observer] = [:]
    private var profileTask: Task<Void, Never>?
    private var generation: UUID?
    private var snapshot: AppSettingsSnapshot?

    init(store: sending VINAppSettingsStore, profiles: any BikeProfileRepository) {
        self.store = store
        self.profiles = profiles
    }

    deinit { profileTask?.cancel() }

    func load() async -> AppSettings {
        refresh(vin: await currentVIN()).settings
    }

    func update(expectedVIN: String, change: AppSettingsChange) async throws -> AppSettingsUpdateResult {
        guard let vin = Self.validVIN(expectedVIN) else { throw AppSettingsUpdateError.invalidVIN }
        let selectedVIN = await currentVIN()
        try Task.checkCancellation()
        guard let selectedVIN else { throw AppSettingsUpdateError.vehicleUnavailable }
        guard vin == selectedVIN else { throw AppSettingsUpdateError.vehicleChanged }
        let settings = try store.load(vin: vin)
        let current = record(settings)
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(current) }
        try store.save(updated, vin: vin)
        return .changed(record(updated))
    }

    func observe() async -> AsyncStream<AppSettingsSnapshot> {
        let current = refresh(vin: await currentVIN())
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppSettingsSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        observers[id] = Observer(continuation: continuation)
        continuation.yield(current)
        if observers.count == 1 { startProfileObservation() }
        return stream
    }

    private func currentVIN() async -> String? {
        Self.validVIN(await profiles.loadProfile()?.vin)
    }

    private static func validVIN(_ value: String?) -> String? {
        guard let value else { return nil }
        let vin = StarkPairingIdentity.normalizedVIN(value)
        return StarkPairingIdentity.isValidVIN(vin) ? vin : nil
    }

    private func startProfileObservation() {
        let previous = profileTask
        previous?.cancel()
        let token = UUID()
        generation = token
        let profiles = profiles
        profileTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled else { return }
            let stream = await profiles.observeProfile()
            for await state in stream {
                guard !Task.isCancelled else { return }
                await self?.profileChanged(state.profile?.vin, generation: token)
            }
        }
    }

    private func profileChanged(_ vin: String?, generation token: UUID) async {
        let vin = Self.validVIN(vin)
        guard generation == token, !Task.isCancelled,
              vin == (await currentVIN()),
              generation == token, !Task.isCancelled else { return }
        _ = refresh(vin: vin)
    }

    private func refresh(vin: String?) -> AppSettingsSnapshot {
        do {
            return record(try store.load(vin: vin))
        } catch {
            if let snapshot, snapshot.settings.vin == vin { return snapshot }
            return record(vin.map { AppSettings().scoped(toVIN: $0) } ?? AppSettings())
        }
    }

    private func record(_ settings: AppSettings) -> AppSettingsSnapshot {
        if let snapshot, snapshot.settings == settings { return snapshot }
        let current = AppSettingsSnapshot(settings: settings, revision: snapshot.map { $0.revision + 1 } ?? 0)
        snapshot = current
        for observer in observers.values { observer.continuation.yield(current) }
        return current
    }

    private func removeObserver(_ id: UUID) async {
        observers[id] = nil
        guard observers.isEmpty else { return }
        generation = nil
        let previous = profileTask
        previous?.cancel()
        await previous?.value
        if generation == nil { profileTask = nil }
    }

    private struct Observer {
        let continuation: AsyncStream<AppSettingsSnapshot>.Continuation
    }
}
