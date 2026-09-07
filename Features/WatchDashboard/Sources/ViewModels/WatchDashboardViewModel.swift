import BikeDomain
import Combine
import SettingsDomain

@MainActor
public final class WatchDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = WatchDashboardViewState()
    @Published public private(set) var debugEvents: [BikeDebugEvent] = []

    private let useCases: WatchDashboardUseCases
    private let mapper: WatchDashboardViewStateMapper
    private let maximumDebugEvents: Int
    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var settings = AppSettings()
    private var settingsRevision: UInt64?
    private var telemetryTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var debugTask: Task<Void, Never>?
    private var settingsTask: Task<Void, Never>?
    private var batteryHealthTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var monitoringStopTask: Task<Void, Never>?
    private var isMonitoringBatteryHealth = false
    private var monitoringGeneration = 0

    public init(
        useCases: WatchDashboardUseCases,
        mapper: WatchDashboardViewStateMapper,
        maximumDebugEvents: Int
    ) {
        self.useCases = useCases
        self.mapper = mapper
        self.maximumDebugEvents = maximumDebugEvents
    }

    deinit {
        telemetryTask?.cancel()
        connectionTask?.cancel()
        debugTask?.cancel()
        settingsTask?.cancel()
        batteryHealthTask?.cancel()
        monitoringTask?.cancel()
        monitoringStopTask?.cancel()
    }

    public func start() {
        guard telemetryTask == nil else { return }
        observeTelemetry()
        observeConnection()
        observeDebugEvents()
        observeSettings()
    }

    public func stop() {
        telemetryTask?.cancel()
        telemetryTask = nil
        connectionTask?.cancel()
        connectionTask = nil
        debugTask?.cancel()
        debugTask = nil
        settingsTask?.cancel()
        settingsTask = nil
        stopBatteryHealthMonitoring()
    }

    private func observeTelemetry() {
        let useCase = useCases.observeTelemetry
        telemetryTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await telemetry in stream {
                guard !Task.isCancelled else { return }
                self?.receive(telemetry)
            }
        }
    }

    private func observeConnection() {
        let useCase = useCases.observeConnection
        connectionTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self?.receive(connection)
            }
        }
    }

    private func observeDebugEvents() {
        let useCase = useCases.observeDebugEvents
        debugTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.receive(event)
            }
        }
    }

    private func observeSettings() {
        let useCase = useCases.observeSettings
        settingsTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.receiveSettings(settings)
            }
        }
    }

    private func receiveSettings(_ snapshot: AppSettingsSnapshot) {
        guard settingsRevision == nil || snapshot.revision > settingsRevision! else { return }
        settingsRevision = snapshot.revision
        settings = snapshot.settings
        updateViewState()
    }

    private func receive(_ telemetry: BikeTelemetry) {
        self.telemetry = telemetry
        if telemetry.runState == .charging {
            startBatteryHealthMonitoringIfNeeded()
        } else {
            stopBatteryHealthMonitoring()
        }
        updateViewState()
    }

    private func receive(_ connection: BikeConnection) {
        guard !mapper.hasRecentTelemetry(telemetry) else {
            updateViewState()
            return
        }
        publish(mapper.unavailable(connectionState: connection.state))
    }

    private func receive(_ event: BikeDebugEvent) {
        debugEvents.insert(event, at: 0)
        if debugEvents.count > maximumDebugEvents {
            debugEvents.removeLast(debugEvents.count - maximumDebugEvents)
        }
    }

    private func startBatteryHealthMonitoringIfNeeded() {
        guard !isMonitoringBatteryHealth, monitoringTask == nil else { return }
        let startMonitoring = useCases.startBatteryHealthMonitoring
        let stopMonitoring = useCases.stopBatteryHealthMonitoring
        let pendingStop = monitoringStopTask
        monitoringGeneration += 1
        let generation = monitoringGeneration
        monitoringTask = Task { [weak self] in
            await pendingStop?.value
            guard
                !Task.isCancelled,
                let self,
                self.monitoringGeneration == generation,
                self.telemetry.runState == .charging
            else { return }
            do {
                try await startMonitoring.execute()
            } catch {
                guard self.monitoringGeneration == generation else { return }
                self.monitoringTask = nil
                return
            }
            guard
                !Task.isCancelled,
                self.monitoringGeneration == generation,
                self.telemetry.runState == .charging
            else {
                await stopMonitoring.execute()
                return
            }
            self.isMonitoringBatteryHealth = true
            self.startObservingBatteryHealth()
            if self.monitoringGeneration == generation {
                self.monitoringTask = nil
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
                self?.batteryHealth = health
                self?.updateViewState()
            }
        }
    }

    private func stopBatteryHealthMonitoring() {
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        let pendingStart = monitoringTask
        monitoringGeneration += 1
        pendingStart?.cancel()
        monitoringTask = nil

        guard isMonitoringBatteryHealth || pendingStart != nil else { return }
        isMonitoringBatteryHealth = false
        let stopMonitoring = useCases.stopBatteryHealthMonitoring
        let previousStop = monitoringStopTask
        monitoringStopTask = Task {
            await pendingStart?.value
            await previousStop?.value
            await stopMonitoring.execute()
        }
    }

    private func updateViewState() {
        publish(mapper.map(
            telemetry: telemetry,
            batteryHealth: batteryHealth,
            settings: settings
        ))
    }

    private func publish(_ nextViewState: WatchDashboardViewState) {
        guard nextViewState != viewState else { return }
        viewState = nextViewState
    }
}
