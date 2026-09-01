import Foundation
import MeasurementPresentation
import Testing

@Suite("Vehicle measurement mapper")
struct VehicleMeasurementMapperTests {
    @Test("Maps metric ride values and symbols")
    func mapsMetricRideMeasurements() {
        let mapper = VehicleMeasurementMapper(measurementSystem: .metric)

        expect(mapper.speed(kilometersPerHour: 100), value: 100, unit: "km/h")
        expect(mapper.distance(kilometers: 10), value: 10, unit: "km")
        expect(mapper.temperature(celsius: 20), value: 20, unit: "°C")
    }

    @Test("Maps US ride values and symbols")
    func mapsUSRideMeasurements() {
        let mapper = VehicleMeasurementMapper(measurementSystem: .us)

        expect(mapper.speed(kilometersPerHour: 100), value: 62.137_119, unit: "mph")
        expect(mapper.distance(kilometers: 10), value: 6.213_712, unit: "mi")
        expect(mapper.temperature(celsius: 20), value: 68, unit: "°F")
    }

    @Test("Maps UK distance and speed while retaining Celsius")
    func mapsUKRideMeasurements() {
        let mapper = VehicleMeasurementMapper(measurementSystem: .uk)

        expect(mapper.speed(kilometersPerHour: 100), value: 62.137_119, unit: "mph")
        expect(mapper.distance(kilometers: 10), value: 6.213_712, unit: "mi")
        expect(mapper.temperature(celsius: 20), value: 20, unit: "°C")
    }

    @Test("Preserves zero and negative electrical values")
    func mapsZeroAndNegativeValues() {
        let mapper = VehicleMeasurementMapper(measurementSystem: .metric)

        expect(mapper.speed(kilometersPerHour: 0), value: 0, unit: "km/h")
        expect(mapper.temperature(celsius: -40), value: -40, unit: "°C")
        expect(mapper.power(watts: 0), value: 0, unit: "kW")
        expect(mapper.power(watts: -1_500), value: -1.5, unit: "kW")
        expect(mapper.current(amperes: 0), value: 0, unit: "A")
        expect(mapper.current(amperes: -2.5), value: -2.5, unit: "A")
    }

    private func expect(
        _ measurement: VehicleMeasurement,
        value: Double,
        unit: String
    ) {
        #expect(abs(measurement.value - value) < 0.000_1)
        #expect(measurement.unit == unit)
    }
}
