import BikeDomain
import Foundation
import RideDashboard
import Testing

@Suite("Ride dashboard mapper")
struct RideDashboardMapperTests {
    @Test("Converts dashboard measurements using the configured measurement system")
    func mapsMeasurementsForLocale() {
        let metricMapper = RideDashboardMeasurementMapper(locale: Locale(identifier: "es_ES"))
        let imperialMapper = RideDashboardMeasurementMapper(locale: Locale(identifier: "en_US"))

        #expect(metricMapper.speed(kilometersPerHour: 42) == .init(value: 42, unit: "km/h"))
        #expect(metricMapper.distance(kilometers: 180) == .init(value: 180, unit: "km"))
        #expect(metricMapper.temperature(celsius: 22) == .init(value: 22, unit: "°C"))
        #expect(imperialMapper.speed(kilometersPerHour: 42).unit == "mph")
        #expect(imperialMapper.distance(kilometers: 180).unit == "mi")
        #expect(imperialMapper.temperature(celsius: 22).unit == "°F")
        #expect(abs(imperialMapper.speedometerMaximum().value - 111.846_814) < 0.001)
    }

    @Test("Maps confirmed telemetry and semantic indicators")
    func mapsLiveTelemetry() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 60),
            mode: .index(3),
            speed: .known(kmh: 42, kmhX10: 420),
            odometer: .known(kilometers: 180, centiKilometers: 18_000),
            statusFlags: BikeStatusFlags(
                isOn: true,
                isInGear: true,
                isFaultActive: true,
                isBrakeActive: true,
                indicatorState: BikeIndicatorState(isHighBeamOn: true, isLeftBlinkerOn: true)
            )
        )

        let state = RideDashboardMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: telemetry,
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "VIN")),
            speedKilometersPerHour: telemetry.speed.kmh,
            measurementSystem: .metric
        )

        #expect(state.hasTelemetry)
        #expect(state.speed == .init(value: 42, unit: "km/h"))
        #expect(state.batteryPercent == 60)
        #expect(state.odometer == .init(value: 180, unit: "km"))
        #expect(state.modeIndex == 3)
        #expect(state.runState == .ride)
        #expect(state.isHighBeamOn)
        #expect(state.isLeftBlinkerOn)
        #expect(state.isBrakeActive)
        #expect(state.isFaultActive)
    }

    @Test("Clamps negative speed")
    func mapsUnavailableValues() {
        let state = RideDashboardMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(speed: .known(kmh: -5, kmhX10: -50)),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "VIN")),
            speedKilometersPerHour: -5,
            measurementSystem: .imperial
        )

        #expect(state.hasTelemetry)
        #expect(state.speed == .init(value: 0, unit: "mph"))
        #expect(state.connectionDetail == "Live telemetry active")
    }

    @Test("Preserves negative speed only during reverse crawl")
    func mapsReverseCrawlSpeed() {
        let state = RideDashboardMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: BikeTelemetry(
                speed: .known(kmh: -3.5, kmhX10: -35),
                statusFlags: BikeStatusFlags(crawlState: .reverse)
            ),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "VIN")),
            speedKilometersPerHour: -3.5,
            measurementSystem: .metric
        )

        #expect(state.runState == .crawlReverse)
        #expect(state.speed == .init(value: -3.5, unit: "km/h"))
    }

    @Test("Does not present stale telemetry outside an active telemetry session")
    func hidesStaleTelemetry() {
        let state = RideDashboardMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: 60),
                speed: .known(kmh: 42, kmhX10: 420),
                odometer: .known(kilometers: 180, centiKilometers: 18_000)
            ),
            connection: BikeConnection(state: .bluetoothPoweredOff),
            speedKilometersPerHour: 42,
            measurementSystem: .imperial
        )

        #expect(!state.hasTelemetry)
        #expect(state.speed == nil)
        #expect(state.odometer == nil)
        #expect(state.batteryPercent == nil)
        #expect(state.connectionDetail == "Bluetooth is off")
    }
}
