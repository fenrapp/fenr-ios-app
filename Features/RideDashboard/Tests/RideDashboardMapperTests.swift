import BikeDomain
import Foundation
@testable import RideDashboard
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
            batteryIndicatorMode: .estimatedRange,
            measurementSystem: .metric
        )

        #expect(state.hasTelemetry)
        #expect(state.speedometer.valueText == "42")
        #expect(state.speedometer.unit == "km/h")
        #expect(abs(state.speedometer.progress - (42.0 / 180.0)) < 0.001)
        #expect(state.speedometer.sourceIndicator == nil)
        #expect(state.speedometer.accessibilityLabel == "Speed 42 km/h")
        #expect(state.showsCompactSpeedReadout)
        #expect(state.odometer.valueText == "180,0 km")
        #expect(state.odometer.accessibilityLabel == "Odometer 180,0 km")
        #expect(state.battery.percentageText == "60%")
        #expect(state.battery.emphasis == .positive)
        #expect(state.showsEstimatedRangeBatteryIndicator)
        #expect(state.gear == .init(display: .text("3"), isActive: true, accessibilityLabel: "Power mode 3"))
        #expect(state.centerMode == .riding)
        #expect(state.indicators.first(where: { $0.id == "highBeam" })?.isActive == true)
        #expect(state.indicators.first(where: { $0.id == "leftTurn" })?.isActive == true)
        #expect(state.indicators.first(where: { $0.id == "brake" })?.isActive == true)
        #expect(state.indicators.first(where: { $0.id == "fault" })?.isActive == true)
    }

    @Test("Shows a source chip only for GPS-assisted speed modes")
    func mapsSpeedSourceIndicator() {
        let mapper = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB"))
        let telemetry = BikeTelemetry(speed: .known(kmh: 42, kmhX10: 420))
        let connection = BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC"))

        let gpsState = mapper.map(
            telemetry: telemetry,
            connection: connection,
            speedKilometersPerHour: 42,
            speedSource: .gps,
            measurementSystem: .metric
        )
        let hybridState = mapper.map(
            telemetry: telemetry,
            connection: connection,
            speedKilometersPerHour: 42,
            speedSource: .hybrid,
            measurementSystem: .metric
        )
        let unavailableState = mapper.map(
            telemetry: telemetry,
            connection: connection,
            speedKilometersPerHour: 42,
            speedSource: .hybrid,
            measurementSystem: .metric,
            isGPSAvailable: false
        )

        #expect(gpsState.speedometer.sourceIndicator == .init(text: "GPS", systemImage: "location.fill"))
        #expect(hybridState.speedometer.sourceIndicator == .init(text: "GPS+", systemImage: "arrow.triangle.branch"))
        #expect(gpsState.speedometer.accessibilityLabel.contains("GPS speed source"))
        #expect(unavailableState.speedometer.sourceIndicator == .init(
            text: "NO GPS",
            systemImage: "location.slash.fill",
            emphasis: .warning
        ))
    }

    @Test("Clamps negative speed")
    func mapsUnavailableValues() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(
                speed: .known(kmh: -5, kmhX10: -50),
                odometer: .known(kilometers: 180, centiKilometers: 18_000),
                statusFlags: .init()
            ),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: -5,
            measurementSystem: .imperial
        )

        #expect(state.hasTelemetry)
        #expect(state.speedometer.valueText == "0")
        #expect(state.speedometer.unit == "mph")
        #expect(state.speedometer.progress == 0)
        #expect(!state.showsCompactSpeedReadout)
        #expect(state.connectionDetail == "Live telemetry active")
        #expect(state.odometer.valueText == "111.8 mi")
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
        #expect(state.speedometer.valueText == "-4")
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
        #expect(state.speedometer.valueText == "--")
        #expect(state.battery == .init())
        #expect(state.odometer == .init())
        #expect(state.gear == .init())
        #expect(state.indicators.allSatisfy { !$0.isActive })
        #expect(state.connectionDetail == "Bluetooth is off")
        #expect(!state.showsConnectionProgress)
    }

    @Test("Maps charging into screen-ready dashboard state")
    func mapsChargingPresentation() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: 50),
                statusFlags: .init(isCharging: true, isChargerConnected: true)
            ),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.centerMode == .charging)
        #expect(state.gear == .init(display: .text("N"), isActive: true, accessibilityLabel: "Gear neutral"))
        #expect(!state.showsCompactSpeedReadout)
    }

    @Test("Shows the charging card for a connected idle charger")
    func mapsConnectedIdleChargerPresentation() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(
                batteryLevel: .known(percent: 50),
                statusFlags: .init(isChargerConnected: true)
            ),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.centerMode == .charging)
    }

    @Test("Maps active mode HP, regen and signed TC without exposing the bike tier")
    func mapsPowerModePresentation() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 60),
            mode: .index(5),
            speed: .known(kmh: 42, kmhX10: 420),
            statusFlags: .init(isOn: true, isInGear: true),
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
            horsepower: "80",
            regenerativeBraking: "40",
            powerTraction: "12.5",
            brakingTraction: "-3",
            showsTractionControl: true,
            isVisible: true
        ))
    }

    @Test("Hides the power mode chip without confirmed HP and regen")
    func mapsPartialPowerModePresentation() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 60),
            mode: .index(2),
            statusFlags: .init(isOn: true, isInGear: true),
            powerModeConfigurations: [1: .init(mapIndex: 1, powerTractionPercent: 20)]
        )
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: telemetry,
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.powerMode == .init())
    }

    @Test("Keeps power and regen available while hiding unavailable TC")
    func hidesUnavailableTractionControl() {
        let telemetry = BikeTelemetry(
            batteryLevel: .known(percent: 60),
            mode: .index(4),
            statusFlags: .init(isOn: true, isInGear: true),
            powerModeConfigurations: [
                3: .init(mapIndex: 3, horsepower: 60, regenerativeBrakingPercent: 50)
            ]
        )
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: telemetry,
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.powerMode.horsepower == "60")
        #expect(state.powerMode.regenerativeBraking == "50")
        #expect(!state.powerMode.showsTractionControl)
    }

}

@Suite("Dashboard indicator status")
struct DashboardIndicatorStatusTests {
    @Test("Does not promote routine braking to the top indicator status")
    func excludesBrakeFromTopIndicators() {
        let brake = DashboardIndicatorViewData(
            id: "brake",
            symbolName: "exclamationmark.circle.fill",
            accessibilityLabel: "Brake",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .critical
        )
        let highBeam = DashboardIndicatorViewData(
            id: "highBeam",
            symbolName: "headlight.high.beam",
            accessibilityLabel: "High beam",
            accessibilityValue: "On",
            isActive: true,
            emphasis: .informational
        )

        #expect(!DashboardIndicatorStatus.hasActiveIndicators([brake]))
        #expect(DashboardIndicatorStatus.hasActiveIndicators([brake, highBeam]))
    }
}

@Suite("Dashboard temperature summary")
struct DashboardTemperatureSummaryTests {
    @Test("Maps the hottest available battery and inverter temperatures")
    func mapsAvailableTemperatures() {
        let telemetry = BikeTelemetry(
            inverterTemperaturesCelsius: [41, nil, 48],
            batteryTelemetry: .init(
                stateOfCharge: .known(percent: 64),
                positiveBMS: bms(temperatureCelsius: 23),
                negativeBMS: bms(temperatureCelsius: 26)
            )
        )
        let mapper = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB"))
        let connection = BikeConnection(state: .receivingTelemetry(peripheralName: "SYNTHETIC"))

        let metric = mapper.map(
            telemetry: telemetry,
            connection: connection,
            speedKilometersPerHour: nil,
            temperatureDisplayMode: .both,
            measurementSystem: .metric
        )
        let imperial = mapper.map(
            telemetry: telemetry,
            connection: connection,
            speedKilometersPerHour: nil,
            temperatureDisplayMode: .both,
            measurementSystem: .imperial
        )

        #expect(metric.temperatureSummary.batteryTemperatureText == "26°C")
        #expect(metric.temperatureSummary.inverterTemperatureText == "48°C")
        #expect(imperial.temperatureSummary.batteryTemperatureText == "79°F")
        #expect(imperial.temperatureSummary.inverterTemperatureText == "118°F")
    }

    @Test("Omits unavailable or non-finite temperatures")
    func omitsUnavailableTemperatures() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB")).map(
            telemetry: .init(
                batteryLevel: .known(percent: 64),
                inverterTemperaturesCelsius: [nil, .nan]
            ),
            connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )

        #expect(state.temperatureSummary == .init())
    }

    @Test("Filters dashboard temperatures by display mode", arguments: [
        (DashboardTemperatureDisplayMode.off, nil, nil),
        (.battery, "26°C", nil),
        (.inverter, nil, "48°C"),
        (.both, "26°C", "48°C")
    ])
    func filtersTemperaturesFromSettings(
        mode: DashboardTemperatureDisplayMode,
        expectedBattery: String?,
        expectedInverter: String?
    ) {
        let telemetry = BikeTelemetry(
            inverterTemperaturesCelsius: [48],
            batteryTelemetry: .init(
                stateOfCharge: .known(percent: 64),
                positiveBMS: bms(temperatureCelsius: 26)
            )
        )
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB")).map(
            telemetry: telemetry,
            connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            speedKilometersPerHour: nil,
            temperatureDisplayMode: mode,
            measurementSystem: .metric
        )

        #expect(state.temperatureSummary.batteryTemperatureText == expectedBattery)
        #expect(state.temperatureSummary.inverterTemperatureText == expectedInverter)
    }

    private func bms(temperatureCelsius: Double) -> BikeBMSSignalsTelemetry {
        .init(
            voltageCandidateRaw: .zero,
            temperatureRaw: .zero,
            temperatureCelsius: temperatureCelsius,
            humidityRaw: .zero,
            humidityPercent: .zero
        )
    }
}
