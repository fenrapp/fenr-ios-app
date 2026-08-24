@preconcurrency import ActivityKit
import BikeDomain
import Foundation
import MeasurementPresentation
import RideDashboard
import RuntimeConfiguration
import SettingsDomain

@MainActor
final class ChargingLiveActivityController {
    private let observeTelemetry: ObserveBikeTelemetryUseCase
    private let observeBatteryHealth: ObserveBikeBatteryHealthUseCase
    private let observeConnection: ObserveBikeConnectionUseCase
    private let observeSettings: ObserveAppSettingsUseCase
    private let startBatteryHealthMonitoring: StartBatteryHealthMonitoringUseCase
    private let stopBatteryHealthMonitoring: StopBatteryHealthMonitoringUseCase
    private let activityClient: ChargingLiveActivityClient
    private let clock: any ChargingLiveActivityClock
    private let updateInterval: TimeInterval

    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var connection = BikeConnection()
    private var mapper = ChargingDashboardMapper()
    private var formatter = VehicleMeasurementTextFormatter()
    private var tasks: [Task<Void, Never>] = []
    private var canShowLiveActivity = false
    private var isStartingBatteryHealthMonitoring = false
    private var isMonitoringBatteryHealth = false
    private var lastContentState: ChargingLiveActivityContentState?
    private var lastUpdateDate: Date?

    init(
        repository: any BikeRepository & BikeBatteryHealthRepository,
        settingsRepository: any AppSettingsRepository,
        activityClient: ChargingLiveActivityClient? = nil,
        clock: any ChargingLiveActivityClock = SystemChargingLiveActivityClock(),
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
            self.activityClient = ActivityKitChargingLiveActivityClient()
        } else {
            self.activityClient = NoOpChargingLiveActivityClient()
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

    private func evaluate() async {
        guard canShowLiveActivity || activityClient.isActive else { return }
        let state = contentState()

        guard telemetry.runState == .charging || activityClient.isActive else {
            await stopMonitoringIfNeeded()
            return
        }

        if !activityClient.isActive {
            guard canShowLiveActivity else { return }
            guard telemetry.runState == .charging else { return }
            do {
                try await activityClient.start(vin: activityVIN, state: state)
                lastContentState = state
                lastUpdateDate = clock.now
                await startMonitoringIfNeeded()
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

        guard shouldUpdate(with: state) else { return }
        await activityClient.update(state: state)
        lastContentState = state
        lastUpdateDate = clock.now
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

    private func shouldUpdate(with state: ChargingLiveActivityContentState) -> Bool {
        guard let lastContentState, let lastUpdateDate else { return true }
        guard state != lastContentState else { return false }
        if state.phase != lastContentState.phase {
            return true
        }
        return clock.now.timeIntervalSince(lastUpdateDate) >= updateInterval
    }

    private func shouldEndActivity(with state: ChargingLiveActivityContentState) -> Bool {
        state.phase == .complete || (telemetry.runState != .charging && state.phase != .connectionLost)
    }

    private func contentState() -> ChargingLiveActivityContentState {
        let dashboardState = mapper.map(telemetry: telemetry, batteryHealth: batteryHealth)
        return ChargingLiveActivityContentState(
            batteryPercent: dashboardState.batteryPercent,
            targetPercent: dashboardState.targetStateOfChargePercent,
            estimatedTimeRemaining: dashboardState.estimatedTimeRemaining,
            powerText: dashboardState.maximumPower.map { formatter.string(from: $0) },
            currentText: dashboardState.reportedCurrent.map { formatter.string(from: $0) },
            temperatureText: dashboardState.batteryTemperature.map { formatter.string(from: $0) },
            phase: phase(dashboardState: dashboardState)
        )
    }

    private func phase(dashboardState: ChargingDashboardViewState) -> ChargingLiveActivityPhase {
        if isConnectionLost {
            return .connectionLost
        }
        if isChargeComplete(dashboardState: dashboardState) {
            return .complete
        }
        if dashboardState.isBalancingAtFullCharge {
            return .balancing
        }
        if telemetry.runState != .charging {
            return .stale
        }
        return .charging
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
        if let target = dashboardState.targetStateOfChargePercent {
            return percent >= target
        }
        return percent >= FENRRuntimeConstants.LiveActivity.completeBatteryPercent
    }

    private var activityVIN: String {
        let vin = telemetry.vin.trimmingCharacters(in: .whitespacesAndNewlines)
        return vin.isEmpty ? "Stark Varg" : vin
    }
}

@MainActor
protocol ChargingLiveActivityClient: AnyObject {
    var isActive: Bool { get }
    func start(vin: String, state: ChargingLiveActivityContentState) async throws
    func update(state: ChargingLiveActivityContentState) async
    func end(state: ChargingLiveActivityContentState) async
}

@available(iOS 16.1, *)
@MainActor
final class ActivityKitChargingLiveActivityClient: ChargingLiveActivityClient {
    private var activity: Activity<ChargingLiveActivityAttributes>?

    var isActive: Bool {
        guard #available(iOS 16.1, *) else { return false }
        return activity != nil || !Activity<ChargingLiveActivityAttributes>.activities.isEmpty
    }

    func start(vin: String, state: ChargingLiveActivityContentState) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw ChargingLiveActivityClientError.unavailable
        }
        if let existing = Activity<ChargingLiveActivityAttributes>.activities.first {
            activity = existing
            await update(state: state)
            return
        }
        activity = try Activity.request(
            attributes: ChargingLiveActivityAttributes(vin: vin),
            contentState: state,
            pushType: nil
        )
    }

    func update(state: ChargingLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.update(using: state)
    }

    func end(state: ChargingLiveActivityContentState) async {
        guard let activity = currentActivity() else { return }
        await activity.end(using: state, dismissalPolicy: .default)
        self.activity = nil
    }

    private func currentActivity() -> Activity<ChargingLiveActivityAttributes>? {
        if let activity { return activity }
        activity = Activity<ChargingLiveActivityAttributes>.activities.first
        return activity
    }
}

@MainActor
private final class NoOpChargingLiveActivityClient: ChargingLiveActivityClient {
    var isActive: Bool { false }
    func start(vin: String, state: ChargingLiveActivityContentState) async throws {
        throw ChargingLiveActivityClientError.unavailable
    }
    func update(state: ChargingLiveActivityContentState) async {}
    func end(state: ChargingLiveActivityContentState) async {}
}

private enum ChargingLiveActivityClientError: Error {
    case unavailable
}

protocol ChargingLiveActivityClock: Sendable {
    var now: Date { get }
}

struct SystemChargingLiveActivityClock: ChargingLiveActivityClock {
    var now: Date { Date() }
}
