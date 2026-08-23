import Foundation
import SettingsDomain

public actor UserDefaultsAppSettingsRepository: AppSettingsRepository {
    private let userDefaults: UserDefaults
    private var continuations: [UUID: AsyncStream<AppSettings>.Continuation] = [:]

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> AppSettings {
        guard
            let data = userDefaults.data(forKey: Constants.settingsKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: Constants.settingsKey)
        continuations.values.forEach { $0.yield(settings) }
    }

    public func observe() -> AsyncStream<AppSettings> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AppSettings>.makeStream()
        continuations[id] = continuation
        continuation.yield(load())
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeContinuation(id) }
        }
        return stream
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private enum Constants {
        static let settingsKey = "fenr.app.settings"
    }
}
