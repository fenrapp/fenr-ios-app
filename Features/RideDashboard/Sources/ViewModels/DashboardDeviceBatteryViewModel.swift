import Combine
import SettingsDomain

@MainActor
public final class DashboardDeviceBatteryViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardDeviceBatteryViewData()

    private let monitor: any DashboardDeviceBatteryMonitoring
    private let loadSettings: LoadAppSettingsUseCase
    private let saveSettings: SaveAppSettingsUseCase
    private var snapshot = DashboardDeviceBatterySnapshot(level: nil, isCharging: false)
    private var displayMode = DashboardDeviceBatteryDisplayMode.icon
    private var observationTask: Task<Void, Never>?
    private var settingsLoadTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var pendingDisplayMode: DashboardDeviceBatteryDisplayMode?

    public init(
        monitor: any DashboardDeviceBatteryMonitoring,
        loadSettings: LoadAppSettingsUseCase,
        saveSettings: SaveAppSettingsUseCase
    ) {
        self.monitor = monitor
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
    }

    deinit {
        observationTask?.cancel()
        settingsLoadTask?.cancel()
        settingsSaveTask?.cancel()
    }

    func start() {
        guard observationTask == nil else { return }
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
        observationTask?.cancel()
        observationTask = nil
        settingsLoadTask?.cancel()
        settingsLoadTask = nil
        monitor.stop()
    }

    func toggleDisplayMode() {
        settingsLoadTask?.cancel()
        settingsLoadTask = nil
        displayMode = displayMode.toggled
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
        viewState = Self.map(snapshot, displayMode: displayMode)
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

    private static func map(
        _ snapshot: DashboardDeviceBatterySnapshot,
        displayMode: DashboardDeviceBatteryDisplayMode
    ) -> DashboardDeviceBatteryViewData {
        guard let level = snapshot.level, level.isFinite, level >= .zero else {
            return .init(displayMode: displayMode)
        }
        let percent = min(max(Int((level * Constants.percentageScale).rounded()), .zero), 100)
        let emphasis: DashboardDeviceBatteryViewData.Emphasis
        if snapshot.isCharging {
            emphasis = .charging
        } else if percent <= Constants.lowBatteryPercent {
            emphasis = .low
        } else {
            emphasis = .normal
        }
        let chargingText = snapshot.isCharging ? ", charging" : ""
        return .init(
            percentageText: "\(percent)%",
            systemImage: batterySymbol(percent: percent),
            emphasis: emphasis,
            accessibilityLabel: "iPhone battery \(percent) percent\(chargingText)",
            displayMode: displayMode
        )
    }

    private static func batterySymbol(percent: Int) -> String {
        switch percent {
        case ...10: "battery.0percent"
        case ...37: "battery.25percent"
        case ...62: "battery.50percent"
        case ...87: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let lowBatteryPercent = 20
    }
}
