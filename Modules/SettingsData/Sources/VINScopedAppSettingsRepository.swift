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

    init(store: sending VINAppSettingsStore, profiles: any BikeProfileRepository) {
        self.store = store
        self.profiles = profiles
    }

    deinit { profileTask?.cancel() }

    func load() async -> AppSettings {
        store.load(vin: await currentVIN())
    }

    func save(_ settings: AppSettings) async {
        guard let vin = settings.vin, vin == (await currentVIN()),
              store.save(settings, vin: vin) else { return }
        publish(settings.scoped(toVIN: vin))
    }

    func observe() async -> AsyncStream<AppSettings> {
        let settings = await load()
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppSettings>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        observers[id] = Observer(continuation: continuation, lastValue: settings)
        continuation.yield(settings)
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
        publish(store.load(vin: vin))
    }

    private func publish(_ settings: AppSettings) {
        for (id, observer) in observers where observer.lastValue != settings {
            observers[id]?.lastValue = settings
            observer.continuation.yield(settings)
        }
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
        let continuation: AsyncStream<AppSettings>.Continuation
        var lastValue: AppSettings
    }
}
