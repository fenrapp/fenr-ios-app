import BikeDomain
import Combine
import SettingsDomain

@MainActor
public final class ChargingDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = ChargingDashboardViewState()

    private let useCases: ChargingDashboardUseCases
    private var mapper: ChargingDashboardMapper
    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var telemetryTask: Task<Void, Never>?
    private var batteryHealthTask: Task<Void, Never>?
    private var settingsTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var isMonitoringBatteryHealth = false

    public init(useCases: ChargingDashboardUseCases, mapper: ChargingDashboardMapper = .init()) {
        self.useCases = useCases
        self.mapper = mapper
    }

    deinit {
        telemetryTask?.cancel()
        batteryHealthTask?.cancel()
        settingsTask?.cancel()
        monitoringTask?.cancel()
    }

    public func start() {
        guard telemetryTask == nil else { return }
        let observeTelemetry = useCases.observeTelemetry
        telemetryTask = Task { [weak self] in
            let stream = await observeTelemetry.execute()
            for await telemetry in stream {
                guard !Task.isCancelled else { return }
                self?.receive(telemetry)
            }
        }
        let observeSettings = useCases.observeSettings
        settingsTask = Task { [weak self] in
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled, let self else { return }
                self.mapper = ChargingDashboardMapper(
                    measurementSystem: settings.measurementSystem,
                    batteryPackCapacity: settings.batteryPackCapacity
                )
                self.render()
            }
        }
    }

    public func stop() {
        telemetryTask?.cancel()
        telemetryTask = nil
        settingsTask?.cancel()
        settingsTask = nil
        stopBatteryHealthMonitoring()
        viewState = ChargingDashboardViewState()
    }

#if DEBUG
    func setPreviewState(_ viewState: ChargingDashboardViewState) {
        self.viewState = viewState
    }
#endif

    private func receive(_ telemetry: BikeTelemetry) {
        self.telemetry = telemetry
        updateBatteryHealthMonitoring()
        render()
    }

    private func receive(_ health: BikeBatteryHealth) {
        batteryHealth = health
        render()
    }

    private func updateBatteryHealthMonitoring() {
        guard telemetry.runState == .charging else {
            stopBatteryHealthMonitoring()
            return
        }
        guard !isMonitoringBatteryHealth, monitoringTask == nil else { return }

        let startMonitoring = useCases.startBatteryHealthMonitoring
        let stopMonitoring = useCases.stopBatteryHealthMonitoring
        monitoringTask = Task { [weak self] in
            do {
                try await startMonitoring.execute()
                guard !Task.isCancelled, let self, self.telemetry.runState == .charging else {
                    await stopMonitoring.execute()
                    return
                }
                isMonitoringBatteryHealth = true
                startObservingBatteryHealth()
                self.monitoringTask = nil
            } catch {
                self?.monitoringTask = nil
            }
        }
    }

    private func startObservingBatteryHealth() {
        guard batteryHealthTask == nil else { return }
        let observeBatteryHealth = useCases.observeBatteryHealth
        batteryHealthTask = Task { [weak self] in
            let stream = await observeBatteryHealth.execute()
            for await health in stream {
                guard !Task.isCancelled else { return }
                self?.receive(health)
            }
        }
    }

    private func stopBatteryHealthMonitoring() {
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        monitoringTask?.cancel()
        monitoringTask = nil

        guard isMonitoringBatteryHealth else { return }
        isMonitoringBatteryHealth = false
        batteryHealth = BikeBatteryHealth()
        let stopMonitoring = useCases.stopBatteryHealthMonitoring
        Task { await stopMonitoring.execute() }
    }

    private func render() {
        viewState = mapper.map(telemetry: telemetry, batteryHealth: batteryHealth)
    }
}
