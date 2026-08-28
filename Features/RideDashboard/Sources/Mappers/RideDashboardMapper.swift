import BikeDomain
import Foundation
import SettingsDomain

public struct RideDashboardMapper: Sendable {
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper
    private let speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper
    private let progressBarMapper: DashboardProgressBarMapper

    public init(
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper,
        speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper,
        progressBarMapper: DashboardProgressBarMapper
    ) {
        self.makeMeasurementMapper = makeMeasurementMapper
        self.speedSourceIndicatorMapper = speedSourceIndicatorMapper
        self.progressBarMapper = progressBarMapper
    }

    public func map(
        telemetry: BikeTelemetry,
        connection: BikeConnection,
        speedKilometersPerHour: Double?,
        speedSource: SpeedSource = .motorcycle,
        progressBarMode: DashboardProgressBarMode = .energy,
        batteryIndicatorMode: DashboardBatteryIndicatorMode = .percentage,
        showsTemperatures: Bool = false,
        measurementSystem: MeasurementSystem,
        isGPSAvailable: Bool = true
    ) -> RideDashboardViewState {
        let measurementMapper = makeMeasurementMapper(measurementSystem)
        let isReceivingTelemetry: Bool
        if case .receivingTelemetry = connection.state {
            isReceivingTelemetry = true
        } else {
            isReceivingTelemetry = false
        }
        let hasTelemetry = isReceivingTelemetry && (telemetry.speed.kmh != nil
            || telemetry.batteryLevel.percent != nil
            || telemetry.odometer.kilometers != nil)
        let speed = hasTelemetry
            ? speedKilometersPerHour.map {
                measurementMapper.speed(
                    kilometersPerHour: displaySpeed(
                        $0,
                        runState: telemetry.runState
                    )
                )
            }
            : nil
        let maximumSpeed = measurementMapper.speedometerMaximum()
        let speedometer = speedometer(
            speed: speed,
            maximum: maximumSpeed,
            source: speedSource,
            isGPSAvailable: isGPSAvailable,
            measurementMapper: measurementMapper
        )
        return RideDashboardViewState(
            speedometer: speedometer,
            progressBar: progressBarMapper.map(
                mode: progressBarMode,
                speedProgress: speedometer.progress,
                telemetry: telemetry,
                hasTelemetry: hasTelemetry,
                measurementMapper: measurementMapper
            ),
            battery: battery(percentage: hasTelemetry ? telemetry.batteryLevel.percent : nil),
            batteryIndicatorMode: batteryIndicatorMode,
            temperatureSummary: DashboardTemperatureSummaryMapper.map(
                telemetry: telemetry, isVisible: hasTelemetry && showsTemperatures, measurementMapper: measurementMapper
            ),
            gear: gear(
                runState: hasTelemetry ? telemetry.runState : .unknown,
                modeIndex: hasTelemetry ? telemetry.mode.displayIndex : nil
            ),
            powerMode: powerMode(telemetry: telemetry, hasTelemetry: hasTelemetry),
            centerMode: hasTelemetry && telemetry.statusFlags.isChargerConnected
                ? .charging
                : .riding,
            connectionDetail: RideDashboardConnectionMapper.text(connection.state),
            hasTelemetry: hasTelemetry,
            showsConnectionProgress: !hasTelemetry && RideDashboardConnectionMapper.showsProgress(connection.state),
            indicators: indicators(flags: telemetry.statusFlags, hasTelemetry: hasTelemetry)
        )
    }

    private func powerMode(
        telemetry: BikeTelemetry,
        hasTelemetry: Bool
    ) -> DashboardPowerModeViewData {
        guard
            hasTelemetry,
            telemetry.runState == .on,
            let mapNumber = telemetry.mode.displayIndex,
            Constants.validPowerModeRange.contains(mapNumber),
            let configuration = telemetry.activePowerModeConfiguration,
            let horsepower = configuration.horsepower,
            let regenerativeBrakingPercent = configuration.regenerativeBrakingPercent
        else {
            return .init()
        }
        return .init(
            map: String(mapNumber),
            horsepower: String(horsepower),
            regenerativeBraking: percent(regenerativeBrakingPercent),
            powerTraction: percent(configuration.powerTractionPercent),
            brakingTraction: percent(configuration.brakingTractionPercent),
            showsTractionControl: configuration.hasTractionControlConfiguration,
            isVisible: true
        )
    }

    private func battery(percentage: Int?) -> RideDashboardViewState.Battery {
        guard let percentage else { return .init() }
        let clampedPercentage = min(max(percentage, .zero), Constants.maximumBatteryPercentage)
        let emphasis: RideDashboardViewState.Battery.Emphasis = switch clampedPercentage {
        case ..<Constants.criticalBatteryPercentage: .critical
        case ..<Constants.warningBatteryPercentage: .warning
        default: .positive
        }
        return .init(
            percentageText: "\(clampedPercentage)%",
            progress: Double(clampedPercentage) / Double(Constants.maximumBatteryPercentage),
            emphasis: emphasis,
            accessibilityLabel: "Battery \(clampedPercentage) percent"
        )
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value.rounded() == value { return "\(Int(value))" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func speedometer(
        speed: RideDashboardMeasurement?,
        maximum: RideDashboardMeasurement,
        source: SpeedSource,
        isGPSAvailable: Bool,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> DashboardSpeedometerViewData {
        let value = speed?.value ?? .zero
        let progress = maximum.value > .zero
            ? min(max(value / maximum.value, .zero), 1)
            : .zero
        let unit = speed?.unit ?? maximum.unit
        let valueText = measurementMapper.number(value, fractionDigits: .zero)
        let sourceIndicator = speedSourceIndicatorMapper.map(
            source,
            isGPSAvailable: isGPSAvailable
        )
        let sourceAccessibility = sourceIndicator.map { ", \($0.text) speed source" } ?? ""
        return .init(
            valueText: valueText,
            unit: unit,
            progress: progress,
            sourceIndicator: sourceIndicator,
            accessibilityLabel: "Speed \(valueText) \(unit)\(sourceAccessibility)"
        )
    }

    private func gear(runState: BikeRunState, modeIndex: Int?) -> DashboardGearViewData {
        switch runState {
        case .unknown:
            .init(display: .text("--"), isActive: false, accessibilityLabel: "Gear unavailable")
        case .off:
            .init(display: .text("OFF"), isActive: false, accessibilityLabel: "Gear off")
        case .neutral, .charging:
            .init(display: .text("N"), isActive: true, accessibilityLabel: "Gear neutral")
        case .on:
            .init(
                display: .text(modeIndex.map(String.init) ?? "--"),
                isActive: true,
                accessibilityLabel: modeIndex.map { "Gear \($0)" } ?? "Gear unavailable"
            )
        case .crawlForward:
            .init(display: .crawlForward, isActive: true, accessibilityLabel: "Crawl forward")
        case .crawlReverse:
            .init(display: .crawlReverse, isActive: true, accessibilityLabel: "Crawl reverse")
        }
    }

    private func indicators(flags: BikeStatusFlags, hasTelemetry: Bool) -> [DashboardIndicatorViewData] {
        [
            indicator(
                id: "highBeam",
                symbolName: "headlight.high.beam",
                label: "High beam",
                isActive: hasTelemetry && flags.indicatorState.isHighBeamOn,
                emphasis: .informational
            ),
            indicator(
                id: "leftTurn",
                symbolName: "arrow.left",
                label: "Left turn",
                isActive: hasTelemetry && flags.indicatorState.isLeftBlinkerOn,
                emphasis: .warning
            ),
            indicator(
                id: "brake",
                symbolName: "exclamationmark.circle.fill",
                label: "Brake",
                isActive: hasTelemetry && flags.isBrakeActive,
                emphasis: .critical
            ),
            indicator(
                id: "rightTurn",
                symbolName: "arrow.right",
                label: "Right turn",
                isActive: hasTelemetry && flags.indicatorState.isRightBlinkerOn,
                emphasis: .warning
            ),
            indicator(
                id: "fault",
                symbolName: "exclamationmark.triangle.fill",
                label: "Fault",
                isActive: hasTelemetry && flags.isFaultActive,
                emphasis: .critical
            )
        ]
    }

    private func indicator(
        id: String,
        symbolName: String,
        label: String,
        isActive: Bool,
        emphasis: DashboardIndicatorEmphasis
    ) -> DashboardIndicatorViewData {
        .init(
            id: id,
            symbolName: symbolName,
            accessibilityLabel: label,
            accessibilityValue: isActive ? "On" : "Off",
            isActive: isActive,
            emphasis: emphasis
        )
    }

    private func displaySpeed(_ speed: Double, runState: BikeRunState) -> Double {
        guard speed < .zero, runState != .crawlReverse else {
            return speed
        }
        return .zero
    }

    private enum Constants {
        static let maximumBatteryPercentage = 100
        static let criticalBatteryPercentage = 21
        static let warningBatteryPercentage = 51
        static let validPowerModeRange = 1 ... 5
    }
}

private enum RideDashboardConnectionMapper {
    static func text(_ state: ConnectionState) -> String {
        switch state {
        case .idle: "Restoring bike session"
        case .reconnecting(_, let attempt, let maximumAttempts): "Reconnecting (\(attempt)/\(maximumAttempts))"
        case .pairingResetRequired(let message): message
        case .scanning: "Scanning for bike"
        case .connecting: "Connecting"
        case .discovering: "Discovering bike services"
        case .authenticating: "Authenticating"
        case .authenticated: "Enabling live telemetry"
        case .subscribed: "Waiting for live telemetry"
        case .receivingTelemetry: "Live telemetry active"
        case .disconnected(let reason): reason ?? "Disconnected"
        case .failed(let message): message
        case .bluetoothUnavailable: "Bluetooth is unavailable"
        case .bluetoothPoweredOff: "Bluetooth is off"
        case .bluetoothUnauthorized: "Bluetooth access is required"
        }
    }

    static func showsProgress(_ state: ConnectionState) -> Bool {
        switch state {
        case .idle,
             .scanning,
             .connecting,
             .discovering,
             .authenticating,
             .authenticated,
             .subscribed,
             .receivingTelemetry,
             .reconnecting:
            true
        case .bluetoothUnavailable,
             .bluetoothUnauthorized,
             .bluetoothPoweredOff,
             .pairingResetRequired,
             .disconnected,
             .failed:
            false
        }
    }
}

private enum DashboardTemperatureSummaryMapper {
    static func map(
        telemetry: BikeTelemetry,
        isVisible: Bool,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> RideDashboardViewState.TemperatureSummary {
        guard isVisible else { return .init() }
        let batteryTemperatures = [
            telemetry.batteryTelemetry.positiveBMS?.temperatureCelsius,
            telemetry.batteryTelemetry.negativeBMS?.temperatureCelsius
        ]
        return .init(
            batteryTemperatureText: temperatureText(
                batteryTemperatures.compactMap { $0 }.filter(\.isFinite).max(),
                measurementMapper: measurementMapper
            ),
            inverterTemperatureText: temperatureText(
                telemetry.inverterTemperaturesCelsius.compactMap { $0 }.filter(\.isFinite).max(),
                measurementMapper: measurementMapper
            )
        )
    }

    private static func temperatureText(
        _ celsius: Double?,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> String? {
        guard let celsius else { return nil }
        let temperature = measurementMapper.temperature(celsius: celsius)
        return measurementMapper.number(temperature.value, fractionDigits: .zero) + temperature.unit
    }
}
