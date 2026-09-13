import BikeDomain
import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing
import VehicleSession

@Suite("Experimental dashboard hours")
struct DashboardExperimentalHoursTests {
    @Test("Shows whole hours without rounding up and preserves the raw counter")
    func mapsProvisionalHours() {
        let now = Date(timeIntervalSince1970: 1_000)
        let telemetry = BikeTelemetry(
            odometer: .known(kilometers: 100, centiKilometers: 10_000),
            experimentalUsageCounter: .init(rawValue: 36_018, sampledAt: now), lastUpdated: now
        )
        let state = map(telemetry)
        #expect(state.experimentalHours?.valueText == "10 h")
        #expect(state.experimentalHours?.rawCounterText == "36018")
        #expect(state.experimentalHours?.accessibilityLabel.contains("Experimental") == true)
        #expect(state.withContinuity(.recovering).experimentalHours == nil)
        #expect(state.withContinuity(.live).experimentalHours == state.experimentalHours)
    }

    @Test("Hides missing, stale and disconnected counters without substituting zero")
    func hidesUnavailableHours() {
        let sampleDate = Date(timeIntervalSince1970: 1_000)
        var telemetry = BikeTelemetry(
            odometer: .known(kilometers: 100, centiKilometers: 10_000), lastUpdated: sampleDate
        )
        #expect(map(telemetry).experimentalHours == nil)
        telemetry.experimentalUsageCounter = .init(rawValue: 0, sampledAt: sampleDate)
        #expect(map(telemetry).experimentalHours?.valueText == "0 h")
        #expect(map(telemetry, connected: false).experimentalHours == nil)
        telemetry.lastUpdated = sampleDate.addingTimeInterval(30)
        #expect(map(telemetry).experimentalHours?.valueText == "0 h")
        telemetry.lastUpdated = sampleDate.addingTimeInterval(31)
        #expect(map(telemetry).experimentalHours == nil)
        telemetry.lastUpdated = sampleDate.addingTimeInterval(-1)
        #expect(map(telemetry).experimentalHours == nil)
        telemetry.lastUpdated = nil
        #expect(map(telemetry).experimentalHours == nil)
    }

    @Test("Counter-only and counter freshness changes invalidate the dashboard cache")
    func invalidatesMappingCache() {
        let sampleDate = Date(timeIntervalSince1970: 1_000)
        var telemetry = BikeTelemetry(
            experimentalUsageCounter: .init(rawValue: 36_000, sampledAt: sampleDate), lastUpdated: sampleDate
        )
        let first = RideDashboardMappingInput(snapshot: .init(telemetry: telemetry))
        telemetry.lastUpdated = sampleDate.addingTimeInterval(1)
        #expect(first == RideDashboardMappingInput(snapshot: .init(telemetry: telemetry)))
        telemetry.experimentalUsageCounter = .init(rawValue: 36_004, sampledAt: sampleDate)
        let second = RideDashboardMappingInput(snapshot: .init(telemetry: telemetry))
        #expect(first != second)
        telemetry.lastUpdated = sampleDate.addingTimeInterval(31)
        #expect(second != RideDashboardMappingInput(snapshot: .init(telemetry: telemetry)))
    }

    @Test("The visibility setting hides the counter immediately and invalidates cached presentation")
    func respectsVisibilitySetting() {
        let now = Date(timeIntervalSince1970: 1_000)
        let telemetry = BikeTelemetry(
            odometer: .known(kilometers: 100, centiKilometers: 10_000),
            experimentalUsageCounter: .init(rawValue: 36_018, sampledAt: now), lastUpdated: now
        )
        let visible = RideDashboardMappingInput(snapshot: .init(
            telemetry: telemetry, settings: .init(showsBikeHours: true)
        ))
        let hidden = RideDashboardMappingInput(snapshot: .init(
            telemetry: telemetry, settings: .init()
        ))
        #expect(visible != hidden)
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB")).map(
            telemetry: telemetry, connection: .init(state: .receivingTelemetry(peripheralName: "SYNTHETIC")),
            speedKilometersPerHour: nil, measurementSystem: .metric
        )
        #expect(state.experimentalHours == nil)
        #expect(state.odometer.valueText == "100.0 km")
    }

    private func map(_ telemetry: BikeTelemetry, connected: Bool = true) -> RideDashboardViewState {
        RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB")).map(
            telemetry: telemetry,
            connection: .init(state: connected ? .receivingTelemetry(peripheralName: "SYNTHETIC") : .idle),
            speedKilometersPerHour: nil, showsBikeHours: true, measurementSystem: .metric
        )
    }
}
