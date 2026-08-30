import Foundation

public struct VehicleMeasurementTextFormatter: Sendable {
    private let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    public func string(
        from measurement: VehicleMeasurement,
        fractionDigits: Int = 1,
        minimumFractionDigits: Int = 0,
        unitSeparator: String = " "
    ) -> String {
        let value = number(
            measurement.value,
            fractionDigits: fractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
        return "\(value)\(unitSeparator)\(measurement.unit)"
    }

    public func number(
        _ value: Double,
        fractionDigits: Int = 1,
        minimumFractionDigits: Int = 0
    ) -> String {
        let precision = normalizedFractionPrecision(
            maximumFractionDigits: fractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
        return value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(precision))
        )
    }

    public func percentage(_ value: Int, fractionDigits: Int = 0) -> String {
        let precision = normalizedFractionPrecision(
            maximumFractionDigits: fractionDigits,
            minimumFractionDigits: 0
        )
        return (Double(value) / Constants.percentDivisor).formatted(
            .percent.precision(.fractionLength(precision)).locale(locale)
        )
    }

    public func voltage(
        _ value: Double,
        fractionDigits: Int = 1,
        minimumFractionDigits: Int = 0
    ) -> String {
        string(
            value,
            unit: UnitElectricPotentialDifference.volts.symbol,
            fractionDigits: fractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
    }

    public func current(_ value: Double, fractionDigits: Int = 1) -> String {
        string(
            value,
            unit: UnitElectricCurrent.amperes.symbol,
            fractionDigits: fractionDigits
        )
    }

    public func power(_ watts: Double, fractionDigits: Int = 1) -> String {
        let isKilowatts = abs(watts) >= Constants.wattsPerKilowatt
        return string(
            isKilowatts ? watts / Constants.wattsPerKilowatt : watts,
            unit: isKilowatts ? UnitPower.kilowatts.symbol : UnitPower.watts.symbol,
            fractionDigits: fractionDigits
        )
    }

    private func normalizedFractionPrecision(
        maximumFractionDigits: Int,
        minimumFractionDigits: Int
    ) -> ClosedRange<Int> {
        let maximum = max(0, maximumFractionDigits)
        let minimum = min(max(0, minimumFractionDigits), maximum)
        return minimum ... maximum
    }

    private func string(
        _ value: Double,
        unit: String,
        fractionDigits: Int,
        minimumFractionDigits: Int = 0
    ) -> String {
        let text = number(
            value,
            fractionDigits: fractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
        return "\(text) \(unit)"
    }

    private enum Constants {
        static let percentDivisor = 100.0
        static let wattsPerKilowatt = 1_000.0
    }
}
