import Foundation
import MeasurementPresentation
import Testing

@Suite("Vehicle measurement mapper")
struct VehicleMeasurementMapperTests {
    @Test("Converts ride measurements using the selected system")
    func convertsRideMeasurements() {
        let metric = VehicleMeasurementMapper(measurementSystem: .metric)
        let imperial = VehicleMeasurementMapper(measurementSystem: .us)

        #expect(metric.speed(kilometersPerHour: 42) == .init(value: 42, unit: "km/h"))
        #expect(metric.distance(kilometers: 180) == .init(value: 180, unit: "km"))
        #expect(metric.temperature(celsius: 22) == .init(value: 22, unit: "°C"))
        #expect(imperial.speed(kilometersPerHour: 42).unit == "mph")
        #expect(imperial.distance(kilometers: 180).unit == "mi")
        #expect(imperial.temperature(celsius: 22).unit == "°F")
    }

    @Test("Formats a measurement with its unit")
    func formatsMeasurementText() {
        let text = VehicleMeasurementTextFormatter(locale: Locale(identifier: "en_US"))
            .string(from: .init(value: 13.6, unit: "A"))

        #expect(text == "13.6 A")
    }

    @Test("Formats shared electrical and percentage presentation values")
    func formatsSharedElectricalValues() {
        let formatter = VehicleMeasurementTextFormatter(locale: Locale(identifier: "en_US"))

        #expect(formatter.percentage(76) == "76%")
        #expect(formatter.voltage(418.2) == "418.2 V")
        #expect(formatter.current(2.5) == "2.5 A")
        #expect(formatter.power(167.3) == "167.3 W")
        #expect(formatter.power(1_000) == "1 kW")
    }

    @Test("Clamps a value to a closed range")
    func clampsValues() {
        #expect((-2.0).clamped(to: 0 ... 1) == 0)
        #expect(2.0.clamped(to: 0 ... 1) == 1)
    }
}
