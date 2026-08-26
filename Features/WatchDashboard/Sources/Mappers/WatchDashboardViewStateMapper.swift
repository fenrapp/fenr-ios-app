import BikeDomain
import Foundation
import MeasurementPresentation
import SettingsDomain

public struct WatchDashboardViewStateMapper: Sendable {
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> VehicleMeasurementMapper
    private let measurementTextFormatter: VehicleMeasurementTextFormatter
    private let timeRemainingFormatStyle: Duration.UnitsFormatStyle
    private let now: @Sendable () -> Date
    private let telemetryFreshnessInterval: TimeInterval

    public init(
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> VehicleMeasurementMapper,
        measurementTextFormatter: VehicleMeasurementTextFormatter,
        timeRemainingFormatStyle: Duration.UnitsFormatStyle,
        now: @escaping @Sendable () -> Date,
        telemetryFreshnessInterval: TimeInterval
    ) {
        self.makeMeasurementMapper = makeMeasurementMapper
        self.measurementTextFormatter = measurementTextFormatter
        self.timeRemainingFormatStyle = timeRemainingFormatStyle
        self.now = now
        self.telemetryFreshnessInterval = telemetryFreshnessInterval
    }

    public func map(
        telemetry: BikeTelemetry,
        batteryHealth: BikeBatteryHealth,
        settings: AppSettings
    ) -> WatchDashboardViewState {
        guard hasRecentTelemetry(telemetry) else {
            return unavailable(detail: "Waiting for telemetry")
        }
        let measurementMapper = makeMeasurementMapper(settings.measurementSystem)
        let isCharging = telemetry.runState == .charging
        return WatchDashboardViewState(
            mode: isCharging ? .charging : .ride,
            batteryPercent: telemetry.batteryLevel.percent,
            gear: gear(for: telemetry),
            odometer: telemetry.odometer.kilometers.map {
                format(measurementMapper.distance(kilometers: $0))
            },
            chargingPower: isCharging
                ? chargingPower(health: batteryHealth, mapper: measurementMapper)
                : nil,
            chargingCurrent: isCharging
                ? chargingCurrent(health: batteryHealth, mapper: measurementMapper)
                : nil,
            batteryTemperature: isCharging
                ? batteryTemperature(health: batteryHealth, mapper: measurementMapper)
                : nil,
            chargeETA: isCharging
                ? chargingETA(telemetry: telemetry, health: batteryHealth, settings: settings)
                : nil
        )
    }

    public func hasRecentTelemetry(_ telemetry: BikeTelemetry) -> Bool {
        guard let lastUpdated = telemetry.lastUpdated else { return false }
        return now().timeIntervalSince(lastUpdated) < telemetryFreshnessInterval
    }

    public func unavailable(connectionState: ConnectionState) -> WatchDashboardViewState {
        unavailable(detail: connectionDetail(connectionState))
    }

    private func unavailable(detail: String) -> WatchDashboardViewState {
        .init(mode: .unavailable(detail: detail))
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

    private func chargingPower(
        health: BikeBatteryHealth,
        mapper: VehicleMeasurementMapper
    ) -> String? {
        guard let status = health.chargingStatus else { return nil }
        return format(mapper.power(watts: status.maximumPowerWatts))
    }

    private func chargingCurrent(
        health: BikeBatteryHealth,
        mapper: VehicleMeasurementMapper
    ) -> String? {
        guard let status = health.chargingStatus else { return nil }
        return format(mapper.current(amperes: status.reportedCurrentAmperes))
    }

    private func batteryTemperature(
        health: BikeBatteryHealth,
        mapper: VehicleMeasurementMapper
    ) -> String? {
        let temperatures = health.temperatures.map(\.celsius)
        guard !temperatures.isEmpty else { return nil }
        let average = temperatures.reduce(0.0, +) / Double(temperatures.count)
        return format(mapper.temperature(celsius: average))
    }

    private func chargingETA(
        telemetry: BikeTelemetry,
        health: BikeBatteryHealth,
        settings: AppSettings
    ) -> String? {
        guard let status = health.chargingStatus else { return nil }
        let stateOfCharge = telemetry.batteryLevel.percent
        let voltage = health.dcBusVoltage.volts
        let targetNotReached = stateOfCharge.map { $0 < status.maximumStateOfChargePercent } ?? false
        let hasVoltage = voltage.map { $0 > .zero } ?? false
        let hasCurrent = status.reportedCurrentAmperes > .zero
        guard
            let stateOfCharge,
            let voltage,
            targetNotReached,
            hasVoltage,
            hasCurrent
        else { return nil }
        let wattHours = Double(status.maximumStateOfChargePercent - stateOfCharge)
            / Constants.percentageScale
            * settings.batteryPackCapacity.wattHours
        let seconds = wattHours / (voltage * status.reportedCurrentAmperes) * Constants.secondsPerHour
        guard seconds.isFinite, seconds > .zero else { return nil }
        return Duration.seconds(seconds).formatted(timeRemainingFormatStyle)
    }

    private func connectionDetail(_ state: ConnectionState) -> String {
        switch state {
        case .reconnecting: "Reconnecting"
        case .scanning: "Looking for bike"
        case .connecting, .discovering, .authenticating, .authenticated, .subscribed: "Connecting"
        case .bluetoothPoweredOff: "Bluetooth is off"
        case .bluetoothUnauthorized: "Bluetooth permission required"
        case .pairingResetRequired: "Forget and re-pair the bike on iPhone"
        case .failed(let message): message
        case .disconnected(let reason): reason ?? "Disconnected"
        default: "Waiting for telemetry"
        }
    }

    private func format(_ measurement: VehicleMeasurement) -> String {
        measurementTextFormatter.string(from: measurement)
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let secondsPerHour = 3_600.0
    }
}
