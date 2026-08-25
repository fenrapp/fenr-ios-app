import BikeDomain
import ChargeControl
import Combine
import SettingsDomain

@MainActor
public final class ChargingDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = ChargingDashboardViewState()

#if DEBUG
    var chargeControlSessionIdentity: ObjectIdentifier {
        ObjectIdentifier(chargeControl)
    }
#endif

    private let useCases: ChargingDashboardUseCases
    private let chargeControl: ChargeControlSession
    private let makeMapper: @Sendable (AppSettings) -> ChargingDashboardMapper
    private var mapper: ChargingDashboardMapper
    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var telemetryTask: Task<Void, Never>?
    private var batteryHealthTask: Task<Void, Never>?
    private var settingsTask: Task<Void, Never>?
    private var monitoringTask: Task<Void, Never>?
    private var monitoringStopTask: Task<Void, Never>?
    private var isMonitoringBatteryHealth = false
    private var monitoringGeneration = 0
    private var chargeControlCancellable: AnyCancellable?

    public init(
        useCases: ChargingDashboardUseCases,
        chargeControl: ChargeControlSession,
        mapper: ChargingDashboardMapper,
        makeMapper: @escaping @Sendable (AppSettings) -> ChargingDashboardMapper
    ) {
        self.useCases = useCases
        self.chargeControl = chargeControl
        self.mapper = mapper
        self.makeMapper = makeMapper
        chargeControlCancellable = chargeControl.$state
            .dropFirst()
            .sink { [weak self] _ in self?.render() }
    }

    deinit {
        telemetryTask?.cancel()
        batteryHealthTask?.cancel()
        settingsTask?.cancel()
        monitoringTask?.cancel()
        monitoringStopTask?.cancel()
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
                self.mapper = self.makeMapper(settings)
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

    public func setChargePowerLimit(watts: Double) {
        chargeControl.setPowerLimit(watts: watts)
    }

    public func setChargeTarget(percent: Double) {
        chargeControl.setTarget(percent: percent)
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
        chargeControl.receive(health)
        render()
    }

    private func updateBatteryHealthMonitoring() {
        guard telemetry.statusFlags.isChargerConnected else {
            stopBatteryHealthMonitoring(resetsChargeControl: true)
            return
        }
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
                self.telemetry.statusFlags.isChargerConnected
            else { return }
            do {
                try await startMonitoring.execute()
                guard
                    !Task.isCancelled,
                    self.monitoringGeneration == generation,
                    self.telemetry.statusFlags.isChargerConnected
                else {
                    await stopMonitoring.execute()
                    return
                }
                isMonitoringBatteryHealth = true
                startObservingBatteryHealth()
                if monitoringGeneration == generation {
                    monitoringTask = nil
                }
            } catch {
                guard self.monitoringGeneration == generation else { return }
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
                self?.receive(health)
            }
        }
    }

    private func stopBatteryHealthMonitoring(resetsChargeControl: Bool = false) {
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        let pendingStart = monitoringTask
        monitoringGeneration += 1
        pendingStart?.cancel()
        monitoringTask = nil

        if resetsChargeControl {
            chargeControl.receive(BikeBatteryHealth())
        }

        guard isMonitoringBatteryHealth || pendingStart != nil else { return }
        isMonitoringBatteryHealth = false
        batteryHealth = BikeBatteryHealth()
        let stopMonitoring = useCases.stopBatteryHealthMonitoring
        let previousStop = monitoringStopTask
        monitoringStopTask = Task {
            await pendingStart?.value
            await previousStop?.value
            await stopMonitoring.execute()
        }
    }

    private func render() {
        viewState = mapper.map(
            telemetry: telemetry,
            batteryHealth: batteryHealth,
            chargeControl: chargeControl.state
        )
    }
}
