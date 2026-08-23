@testable import BikeDiagnostics
import Foundation
import Testing

@MainActor
@Suite("Bike diagnostics speed formatting")
struct BikeDiagnosticsSpeedFormatterTests {
    @Test("Metric locales retain kilometers per hour")
    func formatsMetricSpeed() {
        let locale = Locale(identifier: "es_ES")
        let formatter = BikeDiagnosticsSpeedFormatter(
            measurementSystem: BikeDiagnosticsMeasurementSystem(locale: locale),
            formatter: makeMeasurementFormatter(locale: locale)
        )

        #expect(formatter.string(kilometersPerHour: 42.1) == "42,1 km/h")
    }

    @Test("US locales convert kilometers per hour to miles per hour")
    func formatsImperialSpeed() {
        let locale = Locale(identifier: "en_US")
        let formatter = BikeDiagnosticsSpeedFormatter(
            measurementSystem: BikeDiagnosticsMeasurementSystem(locale: locale),
            formatter: makeMeasurementFormatter(locale: locale)
        )

        #expect(formatter.string(kilometersPerHour: 42.1) == "26.2 mph")
    }

    private func makeMeasurementFormatter(locale: Locale) -> MeasurementFormatter {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }
}
