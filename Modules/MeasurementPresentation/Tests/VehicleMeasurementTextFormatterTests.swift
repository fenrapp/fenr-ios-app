import Foundation
import MeasurementPresentation
import Testing

@Suite("Vehicle measurement text formatter")
struct VehicleMeasurementTextFormatterTests {
    @Test("Formats measurements in an English locale")
    func formatsEnglishMeasurements() {
        let formatter = makeFormatter(localeIdentifier: "en_US")

        #expect(formatter.string(from: .init(value: 13.6, unit: "A")) == "13.6 A")
    }

    @Test("Uses locale decimal separators")
    func formatsSpanishMeasurements() {
        let formatter = makeFormatter(localeIdentifier: "es_ES")

        #expect(formatter.string(from: .init(value: 13.6, unit: "A")) == "13,6 A")
    }

    @Test("Supports a custom unit separator")
    func supportsCustomUnitSeparator() {
        let formatter = makeFormatter()

        #expect(
            formatter.string(
                from: .init(value: 13.6, unit: "A"),
                unitSeparator: ""
            ) == "13.6A"
        )
    }

    @Test("Rounds and pads fractional digits")
    func roundsAndPadsFractionalDigits() {
        let formatter = makeFormatter()

        #expect(formatter.number(1.236, fractionDigits: 2) == "1.24")
        #expect(formatter.number(1, fractionDigits: 2, minimumFractionDigits: 2) == "1.00")
    }

    @Test("Normalizes invalid fraction precision")
    func normalizesInvalidFractionPrecision() {
        let formatter = makeFormatter()

        #expect(formatter.number(1.6, fractionDigits: -1, minimumFractionDigits: -2) == "2")
        #expect(formatter.number(1, fractionDigits: 1, minimumFractionDigits: 4) == "1.0")
        #expect(formatter.percentage(76, fractionDigits: -1) == "76%")
    }

    @Test("Formats percentages and electrical values")
    func formatsSharedElectricalValues() {
        let formatter = makeFormatter()

        #expect(formatter.percentage(76) == "76%")
        #expect(formatter.voltage(418.2) == "418.2 V")
        #expect(formatter.current(-2.5) == "-2.5 A")
    }

    @Test("Selects power units around both kilowatt thresholds")
    func formatsPowerThresholds() {
        let formatter = makeFormatter()

        #expect(formatter.power(0) == "0 W")
        #expect(formatter.power(999.9) == "999.9 W")
        #expect(formatter.power(1_000) == "1 kW")
        #expect(formatter.power(-999.9) == "-999.9 W")
        #expect(formatter.power(-1_000) == "-1 kW")
    }

    private func makeFormatter(localeIdentifier: String = "en_US") -> VehicleMeasurementTextFormatter {
        VehicleMeasurementTextFormatter(locale: Locale(identifier: localeIdentifier))
    }
}
