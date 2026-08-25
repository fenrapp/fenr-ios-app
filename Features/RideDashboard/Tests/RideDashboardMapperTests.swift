import BikeDomain
import Foundation
import RideDashboard
import SettingsDomain
import Testing

@Suite("Ride dashboard mapper")
struct RideDashboardMapperTests {
    @Test("Converts dashboard measurements using the configured measurement system")
    func mapsMeasurementsForLocale() {
        let metricMapper = RideDashboardMapperFactory.makeMeasurementMapper(
            measurementSystem: .system,
            locale: Locale(identifier: "es_ES")
        )
        let imperialMapper = RideDashboardMapperFactory.makeMeasurementMapper(
            measurementSystem: .system,
            locale: Locale(identifier: "en_US")
        )

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

        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: telemetry,
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: telemetry.speed.kmh,
            measurementSystem: .metric
        )

        #expect(state.hasTelemetry)
        #expect(state.speedometer.value == 42)
        #expect(state.speedometer.unit == "km/h")
        #expect(abs(state.speedometer.progress - (42.0 / 180.0)) < 0.001)
        #expect(state.speedometer.emphasis == .informational)
        #expect(state.speedometer.accessibilityLabel == "Speed 42 km/h")
        #expect(state.batteryPercent == 60)
        #expect(state.odometer == .init(valueText: "180", unitText: "km", animationValue: 180))
        #expect(state.gear == .init(display: .text("3"), isActive: true, accessibilityLabel: "Gear 3"))
        #expect(!state.isCharging)
        #expect(state.indicators.first(where: { $0.id == "highBeam" })?.isActive == true)
        #expect(state.indicators.first(where: { $0.id == "leftTurn" })?.isActive == true)
        #expect(state.indicators.first(where: { $0.id == "brake" })?.isActive == true)
        #expect(state.indicators.first(where: { $0.id == "fault" })?.isActive == true)
    }

    @Test("Clamps negative speed")
    func mapsUnavailableValues() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(speed: .known(kmh: -5, kmhX10: -50)),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: -5,
            measurementSystem: .imperial
        )

        #expect(state.hasTelemetry)
        #expect(state.speedometer.value == 0)
        #expect(state.speedometer.unit == "mph")
        #expect(state.speedometer.progress == 0)
        #expect(state.connectionDetail == "Live telemetry active")
    }

    @Test("Preserves negative speed only during reverse crawl")
    func mapsReverseCrawlSpeed() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "es_ES")).map(
            telemetry: BikeTelemetry(
                speed: .known(kmh: -3.5, kmhX10: -35),
                statusFlags: BikeStatusFlags(crawlState: .reverse)
            ),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: -3.5,
            measurementSystem: .metric
        )

        #expect(state.gear == .init(display: .crawlReverse, isActive: true, accessibilityLabel: "Crawl reverse"))
        #expect(state.speedometer.value == -3.5)
    }

    @Test("Does not present stale telemetry outside an active telemetry session")
    func hidesStaleTelemetry() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
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
        #expect(state.speedometer.value == 0)
        #expect(state.odometer == .init())
        #expect(state.batteryPercent == nil)
        #expect(state.gear == .init())
        #expect(state.indicators.allSatisfy { !$0.isActive })
        #expect(state.connectionDetail == "Bluetooth is off")
    }

    @Test("Maps charging into screen-ready dashboard state")
    func mapsChargingPresentation() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: 50),
                statusFlags: .init(isCharging: true)
            ),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.isCharging)
        #expect(state.gear == .init(display: .text("N"), isActive: true, accessibilityLabel: "Gear neutral"))
    }

    @Test("Maps active mode HP, signed TC and effective Alpha tier")
    func mapsPowerModePresentation() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 60),
            mode: .index(5),
            speed: .known(kmh: 42, kmhX10: 420),
            powerModeConfigurations: [
                4: .init(
                    mapIndex: 4,
                    horsepower: 80,
                    regenerativeBrakingPercent: 40,
                    powerTractionPercent: 12.5,
                    brakingTractionPercent: -3
                )
            ],
            detectedPowerTier: .alpha(evidence: [.powerAboveStandard])
        )

        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: telemetry,
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: 42,
            measurementSystem: .metric
        )

        #expect(state.powerMode == .init(
            map: "5",
            horsepower: "80 HP",
            regenerativeBraking: "40%",
            powerTraction: "12.5%",
            brakingTraction: "-3%",
            tierBadge: "ALPHA · 80 MAX"
        ))
    }

    @Test("Keeps unknown active configuration as placeholders")
    func mapsPartialPowerModePresentation() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 60),
            mode: .index(2),
            powerModeConfigurations: [1: .init(mapIndex: 1, powerTractionPercent: 20)]
        )
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: telemetry,
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.powerMode.horsepower == "--")
        #expect(state.powerMode.regenerativeBraking == "--")
        #expect(state.powerMode.powerTraction == "20%")
        #expect(state.powerMode.brakingTraction == "--")
        #expect(state.powerMode.tierBadge == "STANDARD · 60 MAX")
    }
}
