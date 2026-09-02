import BikeDomain
import Foundation
import MeasurementPresentation

@MainActor
public struct BatteryHealthFormatter {
    private let locale: Locale
    private let measurementMapper: VehicleMeasurementMapper
    private let measurementTextFormatter: VehicleMeasurementTextFormatter

    public init(
        locale: Locale,
        measurementMapper: VehicleMeasurementMapper,
        measurementTextFormatter: VehicleMeasurementTextFormatter
    ) {
        self.locale = locale
        self.measurementMapper = measurementMapper
        self.measurementTextFormatter = measurementTextFormatter
    }

    public func percent(_ value: Int?) -> String {
        guard let value else { return BatteryHealthText.placeholder }
        return measurementTextFormatter.percentage(value)
    }

    public func voltage(_ value: Double?) -> String {
        guard let value else { return BatteryHealthText.placeholder }
        return measurementTextFormatter.voltage(value)
    }

    public func cellVoltage(_ value: Double) -> String {
        measurementTextFormatter.voltage(
            value,
            fractionDigits: Constants.cellVoltageFractionDigits,
            minimumFractionDigits: Constants.cellVoltageFractionDigits
        )
    }

    public func temperature(celsius: Double) -> String {
        measurementTextFormatter.string(
            from: measurementMapper.temperature(celsius: celsius),
            unitSeparator: ""
        )
    }

    public func current(amperes: Double) -> String {
        measurementTextFormatter.current(amperes)
    }

    public func power(watts: Double) -> String {
        measurementTextFormatter.power(watts)
    }

    public func voltageDeviation(volts: Double) -> String {
        let sign = volts >= 0 ? "+" : "-"
        let millivolts = abs(volts) * Constants.voltsToMillivolts
        let value = millivolts.formatted(
            .number.precision(.fractionLength(Constants.deviationFractionDigits)).locale(locale)
        )
        return "\(sign)\(value) mV"
    }

    public func date(_ value: Date?) -> String {
        guard let value else { return BatteryHealthText.placeholder }
        return value.formatted(date: .omitted, time: .standard)
    }

    public func chargeState(_ value: BatteryChargeState) -> String {
        switch value {
        case .unknown: BatteryHealthText.placeholder
        case .disconnected: String(localized: .batteryHealthChargeStateDisconnected)
        case .connected: String(localized: .batteryHealthChargeStateConnected)
        case .charging: String(localized: .batteryHealthChargeStateCharging)
        }
    }

    private enum Constants {
        static let cellVoltageFractionDigits = 4
        static let deviationFractionDigits = 0
        static let voltsToMillivolts = 1_000.0
    }
}
