import BikeDomain
import Foundation
import SettingsDomain

public struct RideDashboardMapper: Sendable {
    private let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    public func map(
        telemetry: BikeTelemetry,
        connection: BikeConnection,
        speedKilometersPerHour: Double?,
        measurementSystem: MeasurementSystem
    ) -> RideDashboardViewState {
        let measurementMapper = RideDashboardMeasurementMapper(
            measurementSystem: measurementSystem,
            locale: locale
        )
        let isReceivingTelemetry: Bool
        if case .receivingTelemetry = connection.state {
            isReceivingTelemetry = true
        } else {
            isReceivingTelemetry = false
        }
        let hasTelemetry = isReceivingTelemetry && (telemetry.speed.kmh != nil
            || telemetry.batteryLevel.percent != nil
            || telemetry.odometer.kilometers != nil)
        return RideDashboardViewState(
            speed: hasTelemetry
                ? speedKilometersPerHour.map {
                    measurementMapper.speed(
                        kilometersPerHour: displaySpeed(
                            $0,
                            runState: telemetry.runState
                        )
                    )
                }
                : nil,
            speedometerMaximum: measurementMapper.speedometerMaximum(),
            batteryPercent: hasTelemetry ? telemetry.batteryLevel.percent : nil,
            odometer: hasTelemetry ? telemetry.odometer.kilometers.map(measurementMapper.distance) : nil,
            modeIndex: hasTelemetry ? telemetry.mode.displayIndex : nil,
            runState: hasTelemetry ? runState(telemetry.runState) : .offline,
            connectionDetail: connectionText(connection.state),
            hasTelemetry: hasTelemetry,
            isHighBeamOn: hasTelemetry && telemetry.statusFlags.indicatorState.isHighBeamOn,
            isLeftBlinkerOn: hasTelemetry && telemetry.statusFlags.indicatorState.isLeftBlinkerOn,
            isRightBlinkerOn: hasTelemetry && telemetry.statusFlags.indicatorState.isRightBlinkerOn,
            isBrakeActive: hasTelemetry && telemetry.statusFlags.isBrakeActive,
            isFaultActive: hasTelemetry && telemetry.statusFlags.isFaultActive
        )
    }

    private func runState(_ state: BikeRunState) -> RideDashboardRunState {
        switch state {
        case .unknown: .offline
        case .off: .off
        case .neutral: .neutral
        case .on: .ride
        case .charging: .charging
        case .crawlForward: .crawlForward
        case .crawlReverse: .crawlReverse
        }
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
}
