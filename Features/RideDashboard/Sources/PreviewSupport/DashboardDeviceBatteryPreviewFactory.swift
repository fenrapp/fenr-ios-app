#if DEBUG
import SettingsDomain

@MainActor
enum DashboardDeviceBatteryPreviewFactory {
    static func makeViewModel() -> DashboardDeviceBatteryViewModel {
        let settingsRepository = PreviewDashboardDeviceBatterySettingsRepository()
        let viewModel = DashboardDeviceBatteryViewModel(
            monitor: PreviewDashboardDeviceBatteryMonitor(),
            loadSettings: LoadAppSettingsUseCase(repository: settingsRepository),
            saveSettings: SaveAppSettingsUseCase(repository: settingsRepository),
            mapper: DashboardDeviceBatteryMapper()
        )
        viewModel.setPreviewState(.init(
            percentageText: "64%",
            systemImage: "battery.75percent",
            emphasis: .normal,
            accessibilityLabel: "iPhone battery 64 percent"
        ))
        return viewModel
    }
}

private actor PreviewDashboardDeviceBatterySettingsRepository: AppSettingsRepository {
    private var settings = AppSettings()

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func observe() -> AsyncStream<AppSettings> { AsyncStream { $0.finish() } }
}

private final class PreviewDashboardDeviceBatteryMonitor: DashboardDeviceBatteryMonitoring {
    @MainActor func start() {}
    @MainActor func stop() {}

    @MainActor
    func observe() -> AsyncStream<DashboardDeviceBatterySnapshot> {
        AsyncStream { continuation in
            continuation.yield(.init(level: 0.64, isCharging: false))
        }
    }
}
#endif
