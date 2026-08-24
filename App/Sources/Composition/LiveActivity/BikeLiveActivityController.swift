@preconcurrency import ActivityKit
import BikeDomain
import Foundation
import MeasurementPresentation
import RideDashboard
import RuntimeConfiguration
import SettingsDomain

@MainActor
final class BikeLiveActivityController {
    private let observeTelemetry: ObserveBikeTelemetryUseCase
    private let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    private let observeConnection: ObserveBikeConnectionUseCase
    private let observeSettings: ObserveAppSettingsUseCase
    private let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    private let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    private let activityClient: BikeLiveActivityClient
    private let clock: any BikeLiveActivityClock
    private let updateInterval: TimeInterval

    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var connection = BikeConnection()
    private var settings = AppSettings()
    private var mapper = ChargingDashboardMapper()
    private var formatter = VehicleMeasurementTextFormatter()
    private var tasks: [Task<Void, Never>] = []
    private var canShowLiveActivity = false
    private var isSetupCompleted = false
    private var isStartingBatteryHealthMonitoring = false
    private var isMonitoringBatteryHealth = false
    private var lastContentState: BikeLiveActivityContentState?
    private var lastUpdateDate: Date?

    init(
        repository: any BikeRepository & BikeBatteryHealthRepository,
        settingsRepository: any AppSettingsRepository,
        activityClient: BikeLiveActivityClient? = nil,
        clock: any BikeLiveActivityClock = SystemBikeLiveActivityClock(),
        updateInterval: TimeInterval = FENRRuntimeConstants.LiveActivity.chargingUpdateInterval
    ) {
        observeTelemetry = ObserveBikeTelemetryUseCase(repository: repository)
        observeBatteryHealth = ObserveBikeBatteryHealthUseCase(repository: repository)
        observeConnection = ObserveBikeConnectionUseCase(repository: repository)
        observeSettings = ObserveAppSettingsUseCase(repository: settingsRepository)
        startBatteryHealthMonitoring = StartBatteryHealthMonitoringUseCase(repository: repository)
        stopBatteryHealthMonitoring = StopBatteryHealthMonitoringUseCase(repository: repository)
        if let activityClient {
            self.activityClient = activityClient
        } else if #available(iOS 16.1, *) {
            self.activityClient = ActivityKitBikeLiveActivityClient()
        } else {
            self.activityClient = NoOpBikeLiveActivityClient()
        }
        self.clock = clock
        self.updateInterval = updateInterval
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await observeTelemetry.execute()
            for await telemetry in stream {
                guard !Task.isCancelled else { return }
                self.telemetry = telemetry
                await self.evaluate()
            }
        })
        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await observeBatteryHealth.execute()
            for await batteryHealth in stream {
                guard !Task.isCancelled else { return }
                self.batteryHealth = batteryHealth
                await self.evaluate()
            }
        })
        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await observeConnection.execute()
            for await connection in stream {
                guard !Task.isCancelled else { return }
                self.connection = connection
                await self.evaluate()
            }
        })
        tasks.append(Task { [weak self] in
            guard let self else { return }
            let stream = await observeSettings.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self.mapper = ChargingDashboardMapper(
                    measurementSystem: settings.measurementSystem,
                    batteryPackCapacity: settings.batteryPackCapacity
                )
                self.settings = settings
                self.formatter = VehicleMeasurementTextFormatter()
                await self.evaluate()
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        Task { await stopMonitoringIfNeeded() }
    }

    func setCanShowLiveActivity(_ canShow: Bool) {
        canShowLiveActivity = canShow
        Task { await evaluate() }
    }

    func setIsSetupCompleted(_ isCompleted: Bool) {
        isSetupCompleted = isCompleted
        Task { await evaluate() }
    }

    private func evaluate() async {
        guard canShowLiveActivity || activityClient.isActive else { return }
        let state = contentState()

        if !activityClient.isActive {
            guard canShowLiveActivity else { return }
            guard canStartActivity(with: state) else { return }
            do {
                try await activityClient.start(vin: activityVIN, state: state)
                lastContentState = state
                lastUpdateDate = clock.now
                await updateBatteryHealthMonitoring(for: state)
            } catch {
                await stopMonitoringIfNeeded()
            }
            return
        }

        if shouldEndActivity(with: state) {
            await activityClient.end(state: state)
            await stopMonitoringIfNeeded()
            lastContentState = nil
            lastUpdateDate = nil
            return
        }

        await updateBatteryHealthMonitoring(for: state)
        guard shouldUpdate(with: state) else { return }
        await activityClient.update(state: state)
        lastContentState = state
        lastUpdateDate = clock.now
    }

    private func canStartActivity(with state: BikeLiveActivityContentState) -> Bool {
        isSetupCompleted
            && hasRecentTelemetry
            && hasDisplayableTelemetry
            && isReceivingTelemetry
            && isLiveActivityRunState(telemetry.runState)
            && state.phase != .complete
            && state.mode != .stale
            && state.mode != .connectionLost
    }

    private func updateBatteryHealthMonitoring(for state: BikeLiveActivityContentState) async {
        if state.mode == .charging {
            await startMonitoringIfNeeded()
        } else {
            await stopMonitoringIfNeeded()
        }
    }

    private func startMonitoringIfNeeded() async {
        guard !isMonitoringBatteryHealth, !isStartingBatteryHealthMonitoring else { return }
        isStartingBatteryHealthMonitoring = true
        do {
            try await startBatteryHealthMonitoring.execute()
            isStartingBatteryHealthMonitoring = false
            guard activityClient.isActive, telemetry.runState == .charging else {
                await stopBatteryHealthMonitoring.execute()
                return
            }
            isMonitoringBatteryHealth = true
        } catch {
            isStartingBatteryHealthMonitoring = false
            isMonitoringBatteryHealth = false
        }
    }

    private func stopMonitoringIfNeeded() async {
        guard isMonitoringBatteryHealth else { return }
        isMonitoringBatteryHealth = false
        await stopBatteryHealthMonitoring.execute()
    }

    private func shouldUpdate(with state: BikeLiveActivityContentState) -> Bool {
        guard let lastContentState, let lastUpdateDate else { return true }
        guard state != lastContentState else { return false }
        if state.phase != lastContentState.phase {
            return true
        }
        if state.mode != lastContentState.mode
            || state.runState != lastContentState.runState
            || state.modeIndex != lastContentState.modeIndex
            || state.isFaultActive != lastContentState.isFaultActive
            || state.isConnectionLost != lastContentState.isConnectionLost {
            return true
        }
        return clock.now.timeIntervalSince(lastUpdateDate) >= updateInterval
    }

    private func shouldEndActivity(with state: BikeLiveActivityContentState) -> Bool {
        if !isSetupCompleted { return true }
        if state.phase == .complete { return true }
        if !hasRecentTelemetry, state.mode != .connectionLost, state.mode != .stale { return true }
        if !isLiveActivityRunState(telemetry.runState), !state.isFaultActive, state.mode != .connectionLost {
            return true
        }
        return false
    }

    private func contentState() -> BikeLiveActivityContentState {
        let dashboardState = mapper.map(telemetry: telemetry, batteryHealth: batteryHealth)
        let phase = phase(dashboardState: dashboardState)
        let runState = liveActivityRunState(telemetry.runState)
        let mode = liveActivityMode(phase: phase, runState: runState)
        return BikeLiveActivityContentState(
            batteryPercent: dashboardState.batteryPercent,
            targetPercent: dashboardState.targetStateOfChargePercent,
            estimatedTimeRemaining: dashboardState.estimatedTimeRemaining,
            powerText: dashboardState.maximumPower.map { formatter.string(from: $0) },
            currentText: dashboardState.reportedCurrent.map { formatter.string(from: $0) },
            temperatureText: dashboardState.batteryTemperature.map { formatter.string(from: $0) },
            modeIndex: telemetry.mode.displayIndex,
            speedText: speedText(),
            runState: runState,
            mode: mode,
            phase: phase,
            isFaultActive: telemetry.statusFlags.isFaultActive,
            isConnectionLost: isConnectionLost
        )
    }

    private func phase(dashboardState: ChargingDashboardViewState) -> BikeLiveActivityPhase {
        if isConnectionLost {
            return .connectionLost
        }
        if !hasRecentTelemetry {
            return .stale
        }
        if telemetry.statusFlags.isFaultActive {
            return .fault
        }
        if isChargeComplete(dashboardState: dashboardState) {
            return .complete
        }
        if dashboardState.isBalancingAtFullCharge {
            return .balancing
        }
        switch telemetry.runState {
        case .charging:
            return .charging
        case .on:
            return .riding
        case .neutral:
            return .neutral
        case .crawlForward, .crawlReverse:
            return .crawl
        case .unknown, .off:
            return .stale
        }
    }

    private var isConnectionLost: Bool {
        switch connection.state {
        case .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff, .disconnected, .failed:
            true
        case .idle, .scanning, .connecting, .discovering, .authenticating, .authenticated, .subscribed,
             .receivingTelemetry, .reconnecting:
            false
        }
    }

    private func isChargeComplete(dashboardState: ChargingDashboardViewState) -> Bool {
        guard let percent = dashboardState.batteryPercent else { return false }
        guard telemetry.runState == .charging else { return false }
        if let target = dashboardState.targetStateOfChargePercent {
            return percent >= target
        }
        return percent >= FENRRuntimeConstants.LiveActivity.completeBatteryPercent
    }

    private var hasRecentTelemetry: Bool {
        guard let lastUpdated = telemetry.lastUpdated else { return false }
        return clock.now.timeIntervalSince(lastUpdated) <= FENRRuntimeConstants.Telemetry.freshnessInterval
    }

    private var hasDisplayableTelemetry: Bool {
        telemetry.batteryLevel.percent != nil
            || telemetry.speed.kmh != nil
            || telemetry.odometer.kilometers != nil
            || telemetry.mode.displayIndex != nil
    }

    private var isReceivingTelemetry: Bool {
        if case .receivingTelemetry = connection.state {
            true
        } else {
            false
        }
    }

    private func isLiveActivityRunState(_ runState: BikeRunState) -> Bool {
        switch runState {
        case .charging, .on, .neutral, .crawlForward, .crawlReverse:
            true
        case .unknown, .off:
            false
        }
    }

    private func liveActivityRunState(_ runState: BikeRunState) -> BikeLiveActivityRunState {
        switch runState {
        case .unknown:
            .unknown
        case .off:
            .off
        case .neutral:
            .neutral
        case .on:
            .ride
        case .charging:
            .charging
        case .crawlForward:
            .crawlForward
        case .crawlReverse:
            .crawlReverse
        }
    }

    private func liveActivityMode(
        phase: BikeLiveActivityPhase,
        runState: BikeLiveActivityRunState
    ) -> BikeLiveActivityMode {
        switch phase {
        case .connectionLost:
            .connectionLost
        case .stale:
            .stale
        case .charging, .balancing, .complete:
            .charging
        case .riding, .neutral, .crawl, .fault:
            runState == .charging ? .charging : .riding
        }
    }

    private func speedText() -> String? {
        guard let kilometersPerHour = telemetry.speed.kmh else { return nil }
        let measurement = RideDashboardMeasurementMapper(
            measurementSystem: settings.measurementSystem
        ).speed(kilometersPerHour: displaySpeed(kilometersPerHour))
        return formatter.string(from: measurement, fractionDigits: 0)
    }

    private func displaySpeed(_ speed: Double) -> Double {
        guard speed < .zero, telemetry.runState != .crawlReverse else {
            return speed
        }
        return .zero
    }

    private var activityVIN: String {
        let vin = telemetry.vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return vin.isEmpty ? "Stark Varg" : vin
    }
}

@MainActor
protocol BikeLiveActivityClient: AnyObject {
    var isActive: Bool { get }
    func start(vin: String, state: BikeLiveActivityContentState) async throws
    func update(state: BikeLiveActivityContentState) async
    func end(state: BikeLiveActivityContentState) async
}

@available(iOS 16.1, *)
@MainActor
final class ActivityKitBikeLiveActivityClient: BikeLiveActivityClient {
    private var activity: Activity<BikeLiveActivityAttributes>?

    var isActive: Bool {
        guard #available(iOS 16.1, *) else { return false }
        return activity != nil || !Activity<BikeLiveActivityAttributes>.activities.isEmpty
    }

    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw BikeLiveActivityClientError.unavailable
        }
        if let existing = Activity<BikeLiveActivityAttributes>.activities.first {
            activity = existing
            await update(state: state)
            return
        }
        activity = try Activity.request(
            attributes: BikeLiveActivityAttributes(vin: vin),
            contentState: state,
            pushType: nil
        )
    }

    func update(state: BikeLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.update(using: state)
    }

    func end(state: BikeLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.end(using: state, dismissalPolicy: .default)
        self.activity = nil
    }

    private func currentActivity() -> Activity<BikeLiveActivityAttributes>? {
        if let activity { return activity }
        activity = Activity<BikeLiveActivityAttributes>.activities.first
        return activity
    }
}

@MainActor
private final class NoOpBikeLiveActivityClient: BikeLiveActivityClient {
    var isActive: Bool { false }
    func start(vin: String, state: BikeLiveActivityContentState) async throws {
        throw BikeLiveActivityClientError.unavailable
    }
    func update(state: BikeLiveActivityContentState) async {}
    func end(state: BikeLiveActivityContentState) async {}
}

private enum BikeLiveActivityClientError: Error {
    case unavailable
}

protocol BikeLiveActivityClock: Sendable {
    var now: Date { get }
}

struct SystemBikeLiveActivityClock: BikeLiveActivityClock {
    var now: Date { Date() }
}
