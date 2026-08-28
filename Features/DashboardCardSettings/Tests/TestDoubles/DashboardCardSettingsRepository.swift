import Foundation
import SettingsDomain

actor DashboardCardSettingsRepository: AppSettingsRepository {
    private(set) var settings: AppSettings
    private(set) var savedSettings: [AppSettings] = []
    private(set) var saveCallCount = 0
    private let saveDelay: Duration
    private var continuations: [UUID: AsyncStream<AppSettings>.Continuation] = [:]

    init(
        settings: AppSettings = .init(),
        saveDelay: Duration = .zero
    ) {
        self.settings = settings
        self.saveDelay = saveDelay
    }

    func load() -> AppSettings { settings }

    func save(_ settings: AppSettings) async {
        if saveDelay > .zero {
            try? await Task.sleep(for: saveDelay)
        }
        guard !Task.isCancelled else { return }
        saveCallCount += 1
        guard settings != self.settings else { return }
        self.settings = settings
        savedSettings.append(settings)
        continuations.values.forEach { $0.yield(settings) }
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
