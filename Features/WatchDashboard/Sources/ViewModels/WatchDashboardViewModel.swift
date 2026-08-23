import BikeDomain
import Combine
import Foundation

@MainActor
public final class WatchDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = WatchDashboardViewState()

    private let useCases: WatchDashboardUseCases
    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var telemetryTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var batteryHealthTask: Task<Void, Never>?
    private var isMonitoringBatteryHealth = false

    public init(useCases: WatchDashboardUseCases) {
        self.useCases = useCases
    }

    deinit {
        telemetryTask?.cancel()
        connectionTask?.cancel()
        batteryHealthTask?.cancel()
    }

    public func start() {
        guard telemetryTask == nil else { return }
        observeTelemetry()
        observeConnection()
    }

    public func stop() {
        telemetryTask?.cancel()
        telemetryTask = nil
        connectionTask?.cancel()
        connectionTask = nil
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
        guard !telemetry.lastUpdated.isRecent else {
            updateViewState()
            return
        }
        viewState.mode = .unavailable(detail: connectionDetail(connection.state))
    }

    private func startBatteryHealthMonitoringIfNeeded() {
        guard !isMonitoringBatteryHealth else { return }
        isMonitoringBatteryHealth = true
        let startMonitoring = useCases.startBatteryHealthMonitoring
        let observeBatteryHealth = useCases.observeBatteryHealth
        batteryHealthTask = Task { [weak self] in
            try? await startMonitoring.execute()
            let stream = await observeBatteryHealth.execute()
            for await health in stream {
                guard !Task.isCancelled else { return }
                self?.batteryHealth = health
                self?.updateViewState()
            }
        }
    }

    private func stopBatteryHealthMonitoring() {
        guard isMonitoringBatteryHealth else { return }
        isMonitoringBatteryHealth = false
        batteryHealthTask?.cancel()
        batteryHealthTask = nil
        let stopMonitoring = useCases.stopBatteryHealthMonitoring
        Task { await stopMonitoring.execute() }
    }

    private func updateViewState() {
        guard telemetry.lastUpdated.isRecent else {
            viewState = .init(mode: .unavailable(detail: "Waiting for telemetry"))
            return
        }
        let isCharging = telemetry.runState == .charging
        viewState = WatchDashboardViewState(
            mode: isCharging ? .charging : .ride,
            batteryPercent: telemetry.batteryLevel.percent,
            gear: gear(for: telemetry),
            odometer: telemetry.odometer.kilometers.map(Self.formatDistance),
            chargingPower: isCharging ? chargingPower : nil,
            chargingCurrent: isCharging ? chargingCurrent : nil,
            batteryTemperature: isCharging ? batteryTemperature : nil,
            chargeETA: isCharging ? chargingETA : nil
        )
    }

    private func gear(for telemetry: BikeTelemetry) -> String {
        switch telemetry.runState {
        case .neutral, .charging: "N"
        case .on: telemetry.mode.displayIndex.map(String.init) ?? "R"
        case .crawlForward: "􀋺"
        case .crawlReverse: "􀋻"
        case .off: "OFF"
        case .unknown: "--"
        }
    }

    private var chargingPower: String? {
        guard let status = batteryHealth.chargingStatus else { return nil }
        return Self.numberFormatter.string(from: status.maximumPowerWatts / 1_000) + " kW"
    }

    private var chargingCurrent: String? {
        guard let status = batteryHealth.chargingStatus else { return nil }
        return Self.numberFormatter.string(from: status.reportedCurrentAmperes) + " A"
    }

    private var batteryTemperature: String? {
        let temperatures = batteryHealth.temperatures.map(\.celsius)
        guard !temperatures.isEmpty else { return nil }
        let average = temperatures.reduce(.zero, +) / Double(temperatures.count)
        return Self.numberFormatter.string(from: average) + " C"
    }

    private var chargingETA: String? {
        guard
            let stateOfCharge = telemetry.batteryLevel.percent,
            let voltage = batteryHealth.dcBusVoltage.volts,
            let status = batteryHealth.chargingStatus,
            stateOfCharge < status.maximumStateOfChargePercent,
            voltage > .zero,
            status.reportedCurrentAmperes > .zero
        else { return nil }
        let wattHours = Double(status.maximumStateOfChargePercent - stateOfCharge) / 100 * 7_200
        let seconds = wattHours / (voltage * status.reportedCurrentAmperes) * 3_600
        guard seconds.isFinite, seconds > .zero else { return nil }
        return Self.etaFormatter.string(from: seconds)
    }

    private func connectionDetail(_ state: ConnectionState) -> String {
        switch state {
        case .reconnecting: "Reconnecting"
        case .scanning: "Looking for bike"
        case .connecting, .discovering, .authenticating, .authenticated, .subscribed: "Connecting"
        case .bluetoothPoweredOff: "Bluetooth is off"
        case .bluetoothUnauthorized: "Bluetooth permission required"
        case .failed(let message): message
        case .disconnected(let reason): reason ?? "Disconnected"
        default: "Waiting for telemetry"
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let etaFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }()

    private static func formatDistance(_ kilometers: Double) -> String {
        numberFormatter.string(from: kilometers) + " km"
    }
}

private extension Date? {
    var isRecent: Bool {
        guard let self else { return false }
        return timeIntervalSinceNow > -30
    }
}
