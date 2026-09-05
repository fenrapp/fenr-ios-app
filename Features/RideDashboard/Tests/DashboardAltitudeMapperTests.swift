import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import SettingsDomain
import Testing
import VehicleSession

@Suite("Altitude presentation")
struct DashboardAltitudeMapperTests {
    @Test("Formats metric and imperial readings and places the ruler around the current altitude")
    func mapsUnitsAndScale() throws {
        let mapper = DashboardAltitudeMapper(locale: Locale(identifier: "en_US"))
        let identity = RideVehicleIdentity.temporary(UUID())
        let trip = RideTrip(vehicleIdentity: identity, applicationSessionID: UUID(), startedAt: .distantPast)
            .updatingAltitude(meters: -100).updatingAltitude(meters: 200)
        let metric = mapper.map(.init(
            trip: trip, vehicleIdentity: identity, measurementSystem: .metric,
            motion: .init(altitudeMeters: -40)
        ))
        #expect(metric.isAvailable)
        #expect(metric.valueText == "-40")
        #expect(metric.unitText == "m")
        #expect(metric.minimumText == "-100")
        #expect(metric.maximumText == "200")
        let currentTick = try #require(metric.ticks.first { $0.id == -40 })
        #expect(currentTick.position == 0.5)
        #expect(metric.ticks.first { $0.id == -100 }?.label == "-100")
        #expect(metric.ticks.first { $0.id == -80 }?.label == nil)
        let imperial = mapper.map(.init(
            trip: trip, vehicleIdentity: identity, measurementSystem: .imperial,
            motion: .init(altitudeMeters: 100)
        ))
        #expect(imperial.valueText == "328")
        #expect(imperial.unitText == "ft")
        #expect(imperial.minimumText == "-328")
        #expect(imperial.maximumText == "656")
    }

    @Test("Missing or invalid current readings do not erase trip extrema", arguments: [nil, Double.nan, .infinity])
    func missingReading(meters: Double?) {
        let identity = RideVehicleIdentity.temporary(UUID())
        let trip = RideTrip(vehicleIdentity: identity, applicationSessionID: UUID(), startedAt: .distantPast)
            .updatingAltitude(meters: 20)
        let state = DashboardAltitudeMapper(locale: Locale(identifier: "en_GB")).map(.init(
            trip: trip, vehicleIdentity: identity, motion: .init(altitudeMeters: meters)
        ))
        #expect(!state.isAvailable)
        #expect(state.ticks.isEmpty)
        #expect(state.minimumText == "20")
        #expect(state.maximumText == "20")
    }
}
