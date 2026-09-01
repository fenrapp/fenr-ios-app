import BikeDomain
import Foundation
import RideDashboard
import SettingsDomain
import VehicleSession

struct BikeLiveActivitySnapshot {
    let contentState: BikeLiveActivityContentState
    let hasRecentTelemetry: Bool
    let hasDisplayableTelemetry: Bool
    let isReceivingTelemetry: Bool
    let isLiveRunState: Bool
}

struct BikeLiveActivityStateMapper {
    private let makeDashboardMapper: (AppSettings) -> ChargingDashboardMapper
    private let makeSpeedMapper: (MeasurementSystem) -> RideDashboardMeasurementMapper
    private let telemetryFreshnessInterval: TimeInterval
    private let completeBatteryPercent: Int

    init(
        makeDashboardMapper: @escaping (AppSettings) -> ChargingDashboardMapper,
        makeSpeedMapper: @escaping (MeasurementSystem) -> RideDashboardMeasurementMapper,
        telemetryFreshnessInterval: TimeInterval,
        completeBatteryPercent: Int
    ) {
        self.makeDashboardMapper = makeDashboardMapper
        self.makeSpeedMapper = makeSpeedMapper
        self.telemetryFreshnessInterval = telemetryFreshnessInterval
        self.completeBatteryPercent = completeBatteryPercent
    }

    func map(
        snapshot: VehicleSessionSnapshot,
        now: Date
    ) -> BikeLiveActivitySnapshot {
        let telemetry = snapshot.telemetry
        let connection = snapshot.connection
        let settings = snapshot.settings
        let dashboardState = makeDashboardMapper(settings).map(
            telemetry: telemetry,
            batteryHealth: snapshot.batteryHealth
        )
        let isConnectionLost = isConnectionLost(connection.state)
        let hasRecentTelemetry = telemetry.lastUpdated.map {
            now.timeIntervalSince($0) <= telemetryFreshnessInterval
        } ?? false
        let phase = phase(
            telemetry: telemetry,
            dashboardState: dashboardState,
            isConnectionLost: isConnectionLost,
            hasRecentTelemetry: hasRecentTelemetry
        )
        let runState = liveActivityRunState(telemetry.runState)
        let contentState = BikeLiveActivityContentState(
            batteryPercent: dashboardState.batteryPercent,
            targetPercent: dashboardState.targetPercent,
            estimatedTimeRemaining: dashboardState.estimatedTimeRemaining,
            powerText: metricText(dashboardState.maximumPower),
            currentText: metricText(dashboardState.reportedCurrent),
            temperatureText: metricText(dashboardState.batteryTemperature),
            modeIndex: telemetry.mode.displayIndex,
            speedText: speedText(snapshot: snapshot),
            runState: runState,
            mode: liveActivityMode(phase: phase, runState: runState),
            phase: phase,
            isFaultActive: telemetry.statusFlags.isFaultActive,
            isConnectionLost: isConnectionLost
        )
        return BikeLiveActivitySnapshot(
            contentState: contentState,
            hasRecentTelemetry: hasRecentTelemetry,
            hasDisplayableTelemetry: hasDisplayableTelemetry(telemetry),
            isReceivingTelemetry: isReceivingTelemetry(connection.state),
            isLiveRunState: isLiveActivityRunState(telemetry.runState)
        )
    }

    private func phase(
        telemetry: BikeTelemetry,
        dashboardState: ChargingDashboardViewState,
        isConnectionLost: Bool,
        hasRecentTelemetry: Bool
    ) -> BikeLiveActivityPhase {
        if isConnectionLost { return .connectionLost }
        if !hasRecentTelemetry { return .stale }
        if telemetry.statusFlags.isFaultActive { return .fault }
        if isChargeComplete(telemetry: telemetry, dashboardState: dashboardState) { return .complete }
        if dashboardState.isBalancingAtFullCharge { return .balancing }
        return switch telemetry.runState {
        case .charging: .charging
        case .on: .riding
        case .neutral: .neutral
        case .crawlForward, .crawlReverse: .crawl
        case .unknown, .off: .stale
        }
    }

    private func isChargeComplete(
        telemetry: BikeTelemetry,
        dashboardState: ChargingDashboardViewState
    ) -> Bool {
        guard let percent = dashboardState.batteryPercent else { return false }
        guard telemetry.runState == .charging else { return false }
        return percent >= (dashboardState.targetPercent ?? completeBatteryPercent)
    }

    private func liveActivityRunState(_ runState: BikeRunState) -> BikeLiveActivityRunState {
        switch runState {
        case .unknown: .unknown
        case .off: .off
        case .neutral: .neutral
        case .on: .ride
        case .charging: .charging
        case .crawlForward: .crawlForward
        case .crawlReverse: .crawlReverse
        }
    }

    private func liveActivityMode(
        phase: BikeLiveActivityPhase,
        runState: BikeLiveActivityRunState
    ) -> BikeLiveActivityMode {
        switch phase {
        case .connectionLost: .connectionLost
        case .reconnecting: runState == .charging ? .charging : .riding
        case .stale: .stale
        case .charging, .balancing, .complete: .charging
        case .riding, .neutral, .crawl, .fault:
            runState == .charging ? .charging : .riding
        }
    }

    private func speedText(snapshot: VehicleSessionSnapshot) -> String? {
        guard let kilometersPerHour = snapshot.resolvedSpeedKilometersPerHour else { return nil }
        let mapper = makeSpeedMapper(snapshot.settings.measurementSystem)
        let measurement = mapper.speed(
            kilometersPerHour: displaySpeed(kilometersPerHour, runState: snapshot.telemetry.runState)
        )
        return metricText(mapper.metric(measurement, fractionDigits: 0))
    }

    private func metricText(_ metric: DashboardMetricViewData) -> String? {
        guard metric.animationValue != nil else { return nil }
        guard let unit = metric.unitText else { return metric.valueText }
        return "\(metric.valueText) \(unit)"
    }

    private func displaySpeed(_ speed: Double, runState: BikeRunState) -> Double {
        guard speed < .zero, runState != .crawlReverse else { return speed }
        return .zero
    }

    private func isConnectionLost(_ state: ConnectionState) -> Bool {
        switch state {
        case .bluetoothUnavailable, .bluetoothUnauthorized, .bluetoothPoweredOff, .pairingResetRequired,
             .disconnected, .failed:
            true
        default:
            false
        }
    }

    private func isReceivingTelemetry(_ state: ConnectionState) -> Bool {
        if case .receivingTelemetry = state { true } else { false }
    }

    private func hasDisplayableTelemetry(_ telemetry: BikeTelemetry) -> Bool {
        telemetry.batteryLevel.percent != nil
            || telemetry.speed.kmh != nil
            || telemetry.odometer.kilometers != nil
            || telemetry.mode.displayIndex != nil
    }

    private func isLiveActivityRunState(_ runState: BikeRunState) -> Bool {
        switch runState {
        case .charging, .on, .neutral, .crawlForward, .crawlReverse: true
        case .unknown, .off: false
        }
    }
}
