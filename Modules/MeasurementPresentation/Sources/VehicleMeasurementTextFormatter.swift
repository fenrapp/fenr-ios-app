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
        value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(minimumFractionDigits ... fractionDigits))
        )
    }

    public func percentage(_ value: Int, fractionDigits: Int = 0) -> String {
        (Double(value) / Constants.percentDivisor).formatted(
            .percent.precision(.fractionLength(fractionDigits)).locale(locale)
        )
    }

    public func voltage(
        _ value: Double,
        fractionDigits: Int = 1,
        minimumFractionDigits: Int = 0
    ) -> String {
        string(
            value,
            unit: "V",
            fractionDigits: fractionDigits,
            minimumFractionDigits: minimumFractionDigits
        )
    }

    public func current(_ value: Double, fractionDigits: Int = 1) -> String {
        string(value, unit: "A", fractionDigits: fractionDigits)
    }

    public func power(_ watts: Double, fractionDigits: Int = 1) -> String {
        let isKilowatts = abs(watts) >= Constants.wattsPerKilowatt
        return string(
            isKilowatts ? watts / Constants.wattsPerKilowatt : watts,
            unit: isKilowatts ? "kW" : "W",
            fractionDigits: fractionDigits
        )
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
