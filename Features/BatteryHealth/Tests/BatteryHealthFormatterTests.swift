@testable import BatteryHealth
import Testing

@MainActor
@Suite("Battery Health formatter")
struct BatteryHealthFormatterTests {
    @Test("Percentage uses the system percent format style")
    func percentUsesLocaleAwareFormat() {
        let formatter = makeBatteryHealthFormatter(locale: .init(identifier: "en_US"))

        #expect(formatter.percent(76) == "76%")
    }

    @Test("Temperature follows the selected locale")
    func temperatureUsesLocaleUnit() {
        let metric = makeBatteryHealthFormatter(locale: .init(identifier: "es_ES"))
        let imperial = makeBatteryHealthFormatter(locale: .init(identifier: "en_US"))

        #expect(metric.temperature(celsius: 28.1) == "28,1°C")
        #expect(imperial.temperature(celsius: 28.1) == "82.6°F")
    }

    @Test("Electrical measurements use their native system units")
    func electricalMeasurementsUseNativeFormatters() {
        let formatter = makeBatteryHealthFormatter(locale: .init(identifier: "en_US"))

        #expect(formatter.current(amperes: 2.5) == "2.5 A")
        #expect(formatter.power(watts: 1_000) == "1 kW")
    }
}
