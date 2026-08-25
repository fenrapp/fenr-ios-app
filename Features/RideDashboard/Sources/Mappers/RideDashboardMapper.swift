import BikeDomain
import Foundation
import SettingsDomain

public struct RideDashboardMapper: Sendable {
    private let makeMeasurementMapper: @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper

    public init(
        makeMeasurementMapper: @escaping @Sendable (MeasurementSystem) -> RideDashboardMeasurementMapper
    ) {
        self.makeMeasurementMapper = makeMeasurementMapper
    }

    public func map(
        telemetry: BikeTelemetry,
        connection: BikeConnection,
        speedKilometersPerHour: Double?,
        measurementSystem: MeasurementSystem
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
        let odometer = hasTelemetry
            ? telemetry.odometer.kilometers.map(measurementMapper.distance)
            : nil
        return RideDashboardViewState(
            speedometer: speedometer(speed: speed, maximum: maximumSpeed),
            batteryPercent: hasTelemetry ? telemetry.batteryLevel.percent : nil,
            odometer: measurementMapper.metric(odometer, fractionDigits: 1),
            gear: gear(
                runState: hasTelemetry ? telemetry.runState : .unknown,
                modeIndex: hasTelemetry ? telemetry.mode.displayIndex : nil
            ),
            isCharging: hasTelemetry && telemetry.runState == .charging,
            connectionDetail: connectionText(connection.state),
            hasTelemetry: hasTelemetry,
            indicators: indicators(flags: telemetry.statusFlags, hasTelemetry: hasTelemetry)
        )
    }

    private func speedometer(
        speed: RideDashboardMeasurement?,
        maximum: RideDashboardMeasurement
    ) -> DashboardSpeedometerViewData {
        let value = speed?.value ?? .zero
        let progress = maximum.value > .zero
            ? min(max(value / maximum.value, .zero), 1)
            : .zero
        let emphasis: DashboardGaugeEmphasis = switch progress {
        case ..<Constants.moderateSpeedProgress: .informational
        case ..<Constants.fastSpeedProgress: .positive
        default: .warning
        }
        let unit = speed?.unit ?? maximum.unit
        let formattedValue = Int(value.rounded())
        return .init(
            value: value,
            unit: unit,
            progress: progress,
            emphasis: emphasis,
            accessibilityLabel: "Speed \(formattedValue) \(unit)"
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
                emphasis: .positive
            ),
            indicator(
                id: "brake",
                symbolName: "hand.raised.fill",
                label: "Brake",
                isActive: hasTelemetry && flags.isBrakeActive,
                emphasis: .warning
            ),
            indicator(
                id: "rightTurn",
                symbolName: "arrow.right",
                label: "Right turn",
                isActive: hasTelemetry && flags.indicatorState.isRightBlinkerOn,
                emphasis: .positive
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

    private func connectionText(_ state: ConnectionState) -> String {
        switch state {
        case .reconnecting(_, let attempt, let maximumAttempts): "Reconnecting (\(attempt)/\(maximumAttempts))"
        case .scanning: "Scanning for bike"
        case .connecting: "Connecting"
        case .authenticating: "Authenticating"
        case .receivingTelemetry: "Live telemetry active"
        case .failed(let message): message
        case .bluetoothPoweredOff: "Bluetooth is off"
        case .bluetoothUnauthorized: "Bluetooth access is required"
        default: "Connect your bike from Diagnostics."
        }
    }

    private enum Constants {
        static let moderateSpeedProgress = 0.45
        static let fastSpeedProgress = 0.72
    }
}
