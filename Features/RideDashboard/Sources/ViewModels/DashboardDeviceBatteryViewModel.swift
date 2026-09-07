import Combine
import SettingsDomain

@MainActor
public final class DashboardDeviceBatteryViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardDeviceBatteryViewData(canChangeDisplayMode: false)

    private let monitor: any DashboardDeviceBatteryMonitoring
    private let observeSettings: ObserveAppSettingsUseCase
    private let updateSettings: UpdateAppSettingsUseCase
    private let mapper: DashboardDeviceBatteryMapper
    private var snapshot = DashboardDeviceBatterySnapshot(level: nil, isCharging: false)
    private var pendingChanges = AppSettingsPendingChanges()
    private var settingsError: String?
    private var observationTask: Task<Void, Never>?
    private var settingsObservationTask: Task<Void, Never>?
    private var settingsSaveTask: Task<Void, Never>?
    private var isMonitoring = false
    private var generation = 0

    public init(
        monitor: any DashboardDeviceBatteryMonitoring,
        observeSettings: ObserveAppSettingsUseCase,
        updateSettings: UpdateAppSettingsUseCase,
        mapper: DashboardDeviceBatteryMapper
    ) {
        self.monitor = monitor
        self.observeSettings = observeSettings
        self.updateSettings = updateSettings
        self.mapper = mapper
    }

    isolated deinit {
        observationTask?.cancel()
        settingsObservationTask?.cancel()
        settingsSaveTask?.cancel()
        if isMonitoring { monitor.stop() }
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
        settingsObservationTask = Task { [weak self, observeSettings] in
            let stream = await observeSettings.execute()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.receive(settings: snapshot)
            }
        }
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        generation += 1
        observationTask?.cancel()
        observationTask = nil
        settingsObservationTask?.cancel()
        settingsObservationTask = nil
        settingsSaveTask?.cancel()
        settingsSaveTask = nil
        pendingChanges.removeAll()
        settingsError = nil
        monitor.stop()
        render()
    }

    func toggleDisplayMode() {
        guard isMonitoring else { return }
        do {
            let mode = pendingChanges.settings.dashboardDeviceBatteryDisplayMode.nextVisibleMode
            try pendingChanges.enqueue(.dashboardDeviceBatteryDisplayMode(mode))
            settingsError = nil
            render()
            savePendingChanges()
        } catch {
            settingsError = rideDashboardLocalized(.rideDashboardDeviceBatterySaveError)
            render()
        }
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

    private func receive(settings snapshot: AppSettingsSnapshot) {
        let previousVIN = pendingChanges.confirmed?.settings.vin
        pendingChanges.receive(snapshot)
        if previousVIN != pendingChanges.confirmed?.settings.vin { settingsError = nil }
        render()
    }

    private func render() {
        viewState = mapper.map(
            snapshot: snapshot,
            displayMode: pendingChanges.settings.dashboardDeviceBatteryDisplayMode,
            canChangeDisplayMode: pendingChanges.confirmed?.settings.vin != nil,
            errorText: settingsError
        )
    }

    private func savePendingChanges() {
        guard settingsSaveTask == nil else { return }
        let generation = generation
        settingsSaveTask = Task { [weak self, updateSettings] in
            while let pending = self?.pendingChanges.next {
                do {
                    let result = try await updateSettings.execute(
                        expectedVIN: pending.expectedVIN, change: pending.change
                    )
                    guard !Task.isCancelled, self?.generation == generation else { return }
                    self?.pendingChanges.complete(id: pending.id, result: result)
                } catch {
                    guard !Task.isCancelled, self?.generation == generation else { return }
                    if self?.pendingChanges.reject(id: pending.id) == true {
                        self?.settingsError = rideDashboardLocalized(.rideDashboardDeviceBatterySaveError)
                    }
                }
                self?.render()
            }
            guard !Task.isCancelled, self?.generation == generation else { return }
            self?.settingsSaveTask = nil
        }
    }
}
