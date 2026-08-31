import Combine
import SettingsDomain

@MainActor
public final class DashboardDeviceBatteryViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardDeviceBatteryViewData()

    private let monitor: any DashboardDeviceBatteryMonitoring
    private let loadSettings: LoadAppSettingsUseCase
    private let saveSettings: SaveAppSettingsUseCase
    private let mapper: DashboardDeviceBatteryMapper
    private var snapshot = DashboardDeviceBatterySnapshot(level: nil, isCharging: false)
    private var displayMode = DashboardDeviceBatteryDisplayMode.iconAndText
    private var observationTask: Task<Void, Never>?
    private var settingsLoadTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var pendingDisplayMode: DashboardDeviceBatteryDisplayMode?
    private var isMonitoring = false

    public init(
        monitor: any DashboardDeviceBatteryMonitoring,
        loadSettings: LoadAppSettingsUseCase,
        saveSettings: SaveAppSettingsUseCase,
        mapper: DashboardDeviceBatteryMapper
    ) {
        self.monitor = monitor
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.mapper = mapper
    }

    isolated deinit {
        observationTask?.cancel()
        settingsLoadTask?.cancel()
        settingsSaveTask?.cancel()
        if isMonitoring {
            monitor.stop()
        }
    }

    func start() {
        guard observationTask == nil else { return }
        isMonitoring = true
        monitor.start()
        observationTask = Task { [weak self, monitor] in
            let stream = monitor.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
        loadDisplayMode()
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        observationTask?.cancel()
        observationTask = nil
        settingsLoadTask?.cancel()
        settingsLoadTask = nil
        monitor.stop()
    }

    func toggleDisplayMode() {
        settingsLoadTask?.cancel()
        settingsLoadTask = nil
        displayMode = displayMode.nextVisibleMode
        render()
        save(displayMode)
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardDeviceBatteryViewData) {
        self.viewState = viewState
    }
#endif

    private func receive(_ snapshot: DashboardDeviceBatterySnapshot) {
        self.snapshot = snapshot
        render()
    }

    private func render() {
        viewState = mapper.map(snapshot: snapshot, displayMode: displayMode)
    }

    private func loadDisplayMode() {
        let previousSaveTask = settingsSaveTask
        let loadSettings = loadSettings
        settingsLoadTask = Task { [weak self] in
            await previousSaveTask?.value
            guard !Task.isCancelled else { return }
            let settings = await loadSettings.execute()
            guard !Task.isCancelled else { return }
            self?.receive(displayMode: settings.dashboardDeviceBatteryDisplayMode)
        }
    }

    private func receive(displayMode: DashboardDeviceBatteryDisplayMode) {
        self.displayMode = displayMode
        render()
        settingsLoadTask = nil
    }

    private func save(_ displayMode: DashboardDeviceBatteryDisplayMode) {
        pendingDisplayMode = displayMode
        guard settingsSaveTask == nil else { return }
        let loadSettings = loadSettings
        let saveSettings = saveSettings
        settingsSaveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let displayMode = self?.nextPendingDisplayMode() else { break }
                var settings = await loadSettings.execute()
                guard !Task.isCancelled else { return }
                settings.dashboardDeviceBatteryDisplayMode = displayMode
                await saveSettings.execute(settings)
            }
            guard !Task.isCancelled else { return }
            self?.settingsSaveTask = nil
        }
    }

    private func nextPendingDisplayMode() -> DashboardDeviceBatteryDisplayMode? {
        defer { pendingDisplayMode = nil }
        return pendingDisplayMode
    }

}
