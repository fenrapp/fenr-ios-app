@testable import RideDashboard
import SettingsDomain

@MainActor
final class TestDashboardDeviceBatteryMonitor: DashboardDeviceBatteryMonitoring {
    private let stream: AsyncStream<DashboardDeviceBatterySnapshot>
    private let continuation: AsyncStream<DashboardDeviceBatterySnapshot>.Continuation
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func observe() -> AsyncStream<DashboardDeviceBatterySnapshot> {
        stream
    }

    func send(_ snapshot: DashboardDeviceBatterySnapshot) {
        continuation.yield(snapshot)
    }
}

actor TestDashboardDeviceBatterySettingsRepository: AppSettingsRepository {
    private var settings: AppSettings

    init(settings: AppSettings = .init()) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { AsyncStream { $0.finish() } }
}
