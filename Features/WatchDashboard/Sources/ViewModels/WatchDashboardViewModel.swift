import BikeDomain
import Combine
import Foundation
import MeasurementPresentation
import SettingsDomain

@MainActor
public final class WatchDashboardViewModel: ObservableObject {
    @Published public private(set) var viewState = WatchDashboardViewState()

    private let useCases: WatchDashboardUseCases
    private let measurementTextFormatter: VehicleMeasurementTextFormatter
    private let timeRemainingFormatter: TimeRemainingFormatter
    private var telemetry = BikeTelemetry()
    private var batteryHealth = BikeBatteryHealth()
    private var settings = AppSettings()
    private var telemetryTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var settingsTask: Task<Void, Never>?
    private var batteryHealthTask: Task<Void, Never>?
    private var isMonitoringBatteryHealth = false

    public init(
        useCases: WatchDashboardUseCases,
        measurementTextFormatter: VehicleMeasurementTextFormatter = .init(),
        timeRemainingFormatter: TimeRemainingFormatter = .init()
    ) {
        self.useCases = useCases
        self.measurementTextFormatter = measurementTextFormatter
        self.timeRemainingFormatter = timeRemainingFormatter
    }

    deinit {
        telemetryTask?.cancel()
        connectionTask?.cancel()
        settingsTask?.cancel()
        batteryHealthTask?.cancel()
    }

    public func start() {
        guard telemetryTask == nil else { return }
        observeTelemetry()
        observeConnection()
        observeSettings()
    }

    public func stop() {
        telemetryTask?.cancel()
        telemetryTask = nil
        connectionTask?.cancel()
        connectionTask = nil
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

    private func observeSettings() {
        let useCase = useCases.observeSettings
        settingsTask = Task { [weak self] in
            let stream = await useCase.execute()
            for await settings in stream {
                guard !Task.isCancelled else { return }
                self?.settings = settings
                self?.updateViewState()
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
            odometer: telemetry.odometer.kilometers.map { formatDistance($0) },
            chargingPower: isCharging ? chargingPower : nil,
            chargingCurrent: isCharging ? chargingCurrent : nil,
            batteryTemperature: isCharging ? batteryTemperature : nil,
            chargeETA: isCharging ? chargingETA : nil
        )
    }

    private func gear(for telemetry: BikeTelemetry) -> String {
        switch telemetry.runState {
        case .neutral, .charging: "N"
        case .on: telemetry.mode.displayIndex.map { String($0) } ?? "R"
        case .crawlForward: "􀋺"
        case .crawlReverse: "􀋻"
        case .off: "OFF"
        case .unknown: "--"
        }
    }

    private var chargingPower: String? {
        guard let status = batteryHealth.chargingStatus else { return nil }
        return format(measurementMapper.power(watts: status.maximumPowerWatts))
    }

    private var chargingCurrent: String? {
        guard let status = batteryHealth.chargingStatus else { return nil }
        return format(measurementMapper.current(amperes: status.reportedCurrentAmperes))
    }

    private var batteryTemperature: String? {
        let temperatures = batteryHealth.temperatures.map(\.celsius)
        guard !temperatures.isEmpty else { return nil }
        let average = temperatures.reduce(0.0, +) / Double(temperatures.count)
        return format(measurementMapper.temperature(celsius: average))
    }

    private var chargingETA: String? {
        guard
            let stateOfCharge = telemetry.batteryLevel.percent,
            let voltage = batteryHealth.dcBusVoltage.volts,
            let status = batteryHealth.chargingStatus,
            stateOfCharge < status.maximumStateOfChargePercent,
            voltage > 0,
            status.reportedCurrentAmperes > 0
        else { return nil }
        let wattHours = Double(status.maximumStateOfChargePercent - stateOfCharge)
            / Constants.percentageScale
            * settings.batteryPackCapacity.wattHours
        let seconds = wattHours / (voltage * status.reportedCurrentAmperes) * Constants.secondsPerHour
        guard seconds.isFinite, seconds > 0 else { return nil }
        return timeRemainingFormatter.string(from: seconds)
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

    private func formatDistance(_ kilometers: Double) -> String {
        format(measurementMapper.distance(kilometers: kilometers))
    }

    private func format(_ measurement: VehicleMeasurement) -> String {
        measurementTextFormatter.string(from: measurement)
    }

    private var measurementMapper: VehicleMeasurementMapper {
        VehicleMeasurementMapper(
            measurementSystem: settings.measurementSystem.resolved()
        )
    }

    fileprivate enum Constants {
        static let percentageScale = 100.0
        static let secondsPerHour = 3_600.0
        static let telemetryFreshness: TimeInterval = 30
    }
}

private extension Date? {
    var isRecent: Bool {
        guard let self else { return false }
        return Date().timeIntervalSince(self) < WatchDashboardViewModel.Constants.telemetryFreshness
    }
}
