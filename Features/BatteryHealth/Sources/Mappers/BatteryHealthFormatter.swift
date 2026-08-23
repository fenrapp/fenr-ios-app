import BikeDomain
import Foundation

@MainActor
public struct BatteryHealthFormatter {
    private let locale: Locale
    private let measurementFormatters: BatteryHealthMeasurementFormatters

    public init(locale: Locale, measurementFormatters: BatteryHealthMeasurementFormatters) {
        self.locale = locale
        self.measurementFormatters = measurementFormatters
    }

    public func percent(_ value: Int?) -> String {
        guard let value else { return BatteryHealthText.placeholder }
        return (Double(value) / Constants.percentDivisor).formatted(
            .percent.precision(.fractionLength(Constants.percentageFractionDigits)).locale(locale)
        )
    }

    public func voltage(_ value: Double?) -> String {
        guard let value else { return BatteryHealthText.placeholder }
        return measurementFormatters.voltage(value)
    }

    public func cellVoltage(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(Constants.cellVoltageFractionDigits)).locale(locale))) V"
    }

    public func temperature(celsius: Double) -> String {
        measurementFormatters.temperature(celsius: celsius)
    }

    public func current(amperes: Double) -> String {
        measurementFormatters.current(amperes: amperes)
    }

    public func power(watts: Double) -> String {
        measurementFormatters.power(watts: watts)
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
        case .disconnected: "Disconnected"
        case .connected: "Connected"
        case .charging: "Charging"
        }
    }

    private enum Constants {
        static let percentDivisor = 100.0
        static let percentageFractionDigits = 0
        static let cellVoltageFractionDigits = 4
        static let deviationFractionDigits = 0
        static let voltsToMillivolts = 1_000.0
    }
}
