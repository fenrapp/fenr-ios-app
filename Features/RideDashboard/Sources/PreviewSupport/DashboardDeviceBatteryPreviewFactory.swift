#if DEBUG
import SettingsDomain

@MainActor
enum DashboardDeviceBatteryPreviewFactory {
    static func makeViewModel() -> DashboardDeviceBatteryViewModel {
        let settingsRepository = PreviewDashboardDeviceBatterySettingsRepository()
        let viewModel = DashboardDeviceBatteryViewModel(
            monitor: PreviewDashboardDeviceBatteryMonitor(),
            observeSettings: ObserveAppSettingsUseCase(repository: settingsRepository),
            updateSettings: UpdateAppSettingsUseCase(repository: settingsRepository),
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
    private var settings = AppSettings().scoped(toVIN: "FENRTEST000000001")
    private var revision: UInt64 = 0

    func load() -> AppSettings { settings }
    func update(expectedVIN: String, change: AppSettingsChange) throws -> AppSettingsUpdateResult {
        guard settings.vin == expectedVIN else { throw AppSettingsUpdateError.vehicleChanged }
        let updated = try change.applying(to: settings)
        guard updated != settings else { return .unchanged(.init(settings: settings, revision: revision)) }
        settings = updated
        revision += 1
        return .changed(.init(settings: settings, revision: revision))
    }

    func observe() -> AsyncStream<AppSettingsSnapshot> { AsyncStream { $0.finish() } }
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
