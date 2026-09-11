import BikeDomain
import Foundation
@testable import RideDashboard
import Testing

@Suite("Partial dashboard telemetry")
struct RideDashboardPartialTelemetryTests {
    @Test("Battery-only telemetry opens the dashboard without inventing speed or odometer")
    func batteryOnlyDashboard() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(batteryLevel: .known(percent: 64)),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: nil,
            measurementSystem: .metric
        )
        #expect(state.hasTelemetry)
        #expect(!state.showsConnectionProgress)
        #expect(state.speedometer.valueText == "--")
        #expect(state.odometer == .init())
        #expect(state.gear == .init())
        #expect(state.battery != .init())
    }

    @Test("Speed-only telemetry keeps missing battery and map unavailable")
    func speedOnlyDashboard() {
        let state = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_US")).map(
            telemetry: BikeTelemetry(speed: .known(kmh: 20, kmhX10: 200)),
            connection: BikeConnection(state: .receivingTelemetry(peripheralName: "FENRTEST000000001")),
            speedKilometersPerHour: 20,
            measurementSystem: .metric
        )
        #expect(state.hasTelemetry)
        #expect(state.speedometer.valueText == "20")
        #expect(state.battery == .init())
        #expect(state.gear == .init())
    }

}
