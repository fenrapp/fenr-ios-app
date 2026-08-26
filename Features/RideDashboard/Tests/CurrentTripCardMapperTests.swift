import Foundation
import RideDashboard
import RideSessionDomain
import SettingsDomain
import Testing

@Suite("Current trip card mapper")
struct CurrentTripCardMapperTests {
    @Test("Maps an active trip into metric presentation")
    func mapsActiveTrip() {
        let mapper = RideDashboardMapperFactory.makeCurrentTripMapper(
            locale: Locale(identifier: "en_GB")
        )
        let trip = RideTrip(
            applicationSessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 4_661),
            distanceKilometers: 32.4,
            elapsedSeconds: 3_661,
            averageSpeedKilometersPerHour: 31.86,
            maximumSpeedKilometersPerHour: 91.2
        )

        let state = mapper.map(trip: trip, measurementSystem: .metric)

        #expect(state.durationText == "01:01:01")
        #expect(state.distance.valueText == "32.4")
        #expect(state.distance.unit == "km")
        #expect(state.averageSpeed.valueText == "32")
        #expect(state.maximumSpeed.valueText == "91")
        #expect(state.isActive)
    }

    @Test("Maps the pre-trip ready state")
    func mapsReadyState() {
        let state = RideDashboardMapperFactory.makeCurrentTripMapper(
            locale: Locale(identifier: "en_GB")
        ).map(trip: nil, measurementSystem: .metric)

        #expect(state == .init())
    }

    @Test("Maps a paused trip into its paused controls state")
    func mapsPausedTrip() {
        let date = Date(timeIntervalSince1970: 1_000)
        let trip = RideTrip(
            applicationSessionID: UUID(),
            startedAt: date,
            pausedAt: date.addingTimeInterval(30)
        )

        let state = RideDashboardMapperFactory.makeCurrentTripMapper(
            locale: Locale(identifier: "en_GB")
        ).map(trip: trip, measurementSystem: .metric)

        #expect(state.statusText == "PAUSED")
        #expect(state.isPaused)
        #expect(state.accessibilityLabel.contains("paused"))
    }

    @Test("Maps the selected speed source for the distance row")
    func mapsSpeedSourceIndicator() {
        let mapper = RideDashboardMapperFactory.makeCurrentTripMapper(
            locale: Locale(identifier: "en_GB")
        )

        let normal = mapper.map(
            trip: nil,
            measurementSystem: .metric,
            speedSource: .motorcycle
        )
        let gps = mapper.map(
            trip: nil,
            measurementSystem: .metric,
            speedSource: .gps
        )
        let hybrid = mapper.map(
            trip: nil,
            measurementSystem: .metric,
            speedSource: .hybrid
        )
        let unavailable = mapper.map(
            trip: nil,
            measurementSystem: .metric,
            speedSource: .gps,
            isGPSAvailable: false
        )

        #expect(normal.speedSourceIndicator == nil)
        #expect(gps.speedSourceIndicator?.text == "GPS")
        #expect(hybrid.speedSourceIndicator?.text == "GPS+")
        #expect(gps.accessibilityLabel.contains("GPS speed source"))
        #expect(unavailable.speedSourceIndicator?.text == "NO GPS")
        #expect(unavailable.speedSourceIndicator?.emphasis == .warning)
    }
}
