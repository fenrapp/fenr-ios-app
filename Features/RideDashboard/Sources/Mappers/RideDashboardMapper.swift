import BikeDomain
import Foundation
import SettingsDomain

public struct RideDashboardMapper: Sendable {
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper
    private let speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper
    private let progressBarMapper: DashboardProgressBarMapper
    private let connectionMapper: RideDashboardConnectionMapper
    private let temperatureMapper: DashboardTemperatureSummaryMapper
    private let compactSpeedVisibilityMapper: DashboardCompactSpeedVisibilityMapper

    public init(
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper,
        speedSourceIndicatorMapper: DashboardSpeedSourceIndicatorMapper,
        progressBarMapper: DashboardProgressBarMapper,
        connectionMapper: RideDashboardConnectionMapper,
        temperatureMapper: DashboardTemperatureSummaryMapper,
        compactSpeedVisibilityMapper: DashboardCompactSpeedVisibilityMapper
    ) {
        self.makeMeasurementMapper = makeMeasurementMapper
        self.speedSourceIndicatorMapper = speedSourceIndicatorMapper
        self.progressBarMapper = progressBarMapper
        self.connectionMapper = connectionMapper
        self.temperatureMapper = temperatureMapper
        self.compactSpeedVisibilityMapper = compactSpeedVisibilityMapper
    }

    func measurementMapper(for system: MeasurementSystem) -> RideDashboardMeasurementMapper {
        makeMeasurementMapper(system)
    }

    public func map(
        telemetry: BikeTelemetry,
        connection: BikeConnection,
        speedKilometersPerHour: Double?,
        speedSource: SpeedSource = .motorcycle,
        progressBarMode: DashboardProgressBarMode = .energy,
        batteryIndicatorMode: DashboardBatteryIndicatorMode = .percentage,
        temperatureDisplayMode: DashboardTemperatureDisplayMode = .off,
        measurementSystem: MeasurementSystem,
        isGPSAvailable: Bool = true,
        powerModeNames: [Int: PowerModeName] = [:],
        using measurementMapper: RideDashboardMeasurementMapper? = nil
    ) -> RideDashboardViewState {
        let measurementMapper = measurementMapper ?? makeMeasurementMapper(measurementSystem)
        let hasTelemetry = connectionMapper.hasTelemetry(telemetry, connection: connection)
        let speed = hasTelemetry
            ? speedKilometersPerHour.map {
                measurementMapper.speed(
                    kilometersPerHour: connectionMapper.displaySpeed(
                        $0,
                        runState: telemetry.runState
                    )
                )
            }
            : nil
        let maximumSpeed = measurementMapper.speedometerMaximum()
        let powerModeName = telemetry.mode.powerModeConfigurationIndex
            .flatMap { powerModeNames[$0]?.value }
        let temperatureMode = hasTelemetry ? temperatureDisplayMode : .off
        let speedometer = speedometer(
            speed: speed,
            maximum: maximumSpeed,
            source: speedSource,
            isGPSAvailable: isGPSAvailable,
            measurementMapper: measurementMapper
        )
        return RideDashboardViewState(
            speedometer: speedometer,
            showsCompactSpeedReadout: hasTelemetry
                && compactSpeedVisibilityMapper.isVisible(for: telemetry.runState),
            odometer: odometer(
                kilometers: hasTelemetry ? telemetry.odometer.kilometers : nil,
                measurementMapper: measurementMapper
            ),
            progressBar: progressBarMapper.map(
                mode: progressBarMode,
                speedProgress: speedometer.progress,
                telemetry: telemetry,
                hasTelemetry: hasTelemetry,
                measurementMapper: measurementMapper
            ),
            battery: battery(percentage: hasTelemetry ? telemetry.batteryLevel.percent : nil),
            showsEstimatedRangeBatteryIndicator: batteryIndicatorMode == .estimatedRange,
            temperatureSummary: temperatureMapper.map(telemetry, mode: temperatureMode, using: measurementMapper),
            gear: DashboardGearMapper.map(
                runState: hasTelemetry ? telemetry.runState : .unknown,
                modeIndex: hasTelemetry ? telemetry.mode.displayIndex : nil,
                modeName: hasTelemetry ? powerModeName : nil
            ),
            powerMode: powerMode(
                telemetry: telemetry,
                hasTelemetry: hasTelemetry,
                modeName: powerModeName
            ),
            centerMode: hasTelemetry && telemetry.statusFlags.isChargerConnected
                ? .charging
                : .riding,
            connectionDetail: connectionMapper.text(connection.state),
            hasTelemetry: hasTelemetry,
            showsConnectionProgress: !hasTelemetry && connectionMapper.showsProgress(connection.state),
            indicators: indicators(flags: telemetry.statusFlags, hasTelemetry: hasTelemetry)
        )
    }

    private func powerMode(
        telemetry: BikeTelemetry,
        hasTelemetry: Bool,
        modeName: String?
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
            map: modeName ?? String(mapNumber),
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
            accessibilityLabel: rideDashboardLocalized(.rideDashboardAccessibilityBatteryPercent(clampedPercentage))
        )
    }

    private func odometer(
        kilometers: Double?,
        measurementMapper: RideDashboardMeasurementMapper
    ) -> DashboardOdometerViewData {
        guard let kilometers, kilometers.isFinite else { return .init() }
        let distance = measurementMapper.distance(kilometers: kilometers)
        let value = measurementMapper.number(
            distance.value,
            fractionDigits: 1,
            minimumFractionDigits: 1
        )
        let text = "\(value) \(distance.unit)"
        return .init(
            valueText: text,
            accessibilityLabel: rideDashboardLocalized(.rideDashboardAccessibilityOdometer(text))
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
        let sourceIndicator = speedSourceIndicatorMapper.map(source, isGPSAvailable: isGPSAvailable)
        return .init(
            valueText: valueText,
            unit: unit,
            progress: progress,
            sourceIndicator: sourceIndicator,
            accessibilityLabel: sourceIndicator.map {
                rideDashboardLocalized(.rideDashboardAccessibilitySpeedWithSource(valueText, unit, $0.text))
            } ?? rideDashboardLocalized(.rideDashboardAccessibilitySpeed(valueText, unit))
        )
    }

    private func indicators(flags: BikeStatusFlags, hasTelemetry: Bool) -> [DashboardIndicatorViewData] {
        [
            indicator(
                id: "highBeam",
                symbolName: "headlight.high.beam",
                label: rideDashboardLocalized(.rideDashboardIndicatorHighBeam),
                isActive: hasTelemetry && flags.indicatorState.isHighBeamOn,
                emphasis: .informational
            ),
            indicator(
                id: "leftTurn",
                symbolName: "arrow.left",
                label: rideDashboardLocalized(.rideDashboardIndicatorLeftTurn),
                isActive: hasTelemetry && flags.indicatorState.isLeftBlinkerOn,
                emphasis: .warning
            ),
            indicator(
                id: "brake",
                symbolName: "exclamationmark.circle.fill",
                label: rideDashboardLocalized(.rideDashboardIndicatorBrake),
                isActive: hasTelemetry && flags.isBrakeActive,
                emphasis: .critical
            ),
            indicator(
                id: "rightTurn",
                symbolName: "arrow.right",
                label: rideDashboardLocalized(.rideDashboardIndicatorRightTurn),
                isActive: hasTelemetry && flags.indicatorState.isRightBlinkerOn,
                emphasis: .warning
            ),
            indicator(
                id: "fault",
                symbolName: "exclamationmark.triangle.fill",
                label: rideDashboardLocalized(.rideDashboardIndicatorFault),
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
            accessibilityValue: rideDashboardLocalized(
                isActive ? .rideDashboardIndicatorStateOn : .rideDashboardIndicatorStateOff
            ),
            isActive: isActive,
            emphasis: emphasis
        )
    }

    private enum Constants {
        static let maximumBatteryPercentage = 100
        static let criticalBatteryPercentage = 21
        static let warningBatteryPercentage = 51
        static let validPowerModeRange = 1 ... 5
    }
}
