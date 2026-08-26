import Foundation
import RideDashboard
import RideSessionDomain
import SettingsDomain
import Testing

@Suite("Trip statistics card mapper")
struct TripStatisticsCardMapperTests {
    @Test("Maps an aggregate into display-ready statistics")
    func mapsStatistics() {
        let state = RideDashboardMapperFactory.makeTripStatisticsMapper(
            locale: Locale(identifier: "en_GB")
        ).map(
            RideTripStatistics(
                tripCount: 42,
                totalDistanceKilometers: 1_284.64,
                totalElapsedSeconds: 138_240,
                averageSpeedKilometersPerHour: 40.6,
                maximumSpeedKilometersPerHour: 137.2
            ),
            measurementSystem: .metric
        )

        #expect(state.statusText == "42 SAVED TRIPS")
        #expect(state.totalDistance.valueText == "1,284.6")
        #expect(state.totalDistance.unit == "km")
        #expect(state.totalDuration.valueText == "38:24")
        #expect(state.averageSpeed.valueText == "41")
        #expect(state.maximumSpeed.valueText == "137")
        #expect(!state.isLoading)
    }

    @Test("Maps an empty history without special UI calculations")
    func mapsEmptyStatistics() {
        let state = RideDashboardMapperFactory.makeTripStatisticsMapper(
            locale: Locale(identifier: "en_GB")
        ).map(.init(), measurementSystem: .metric)

        #expect(state.statusText == "NO SAVED TRIPS")
        #expect(state.totalDistance.valueText == "0")
        #expect(state.accessibilityLabel.contains("0 SAVED TRIPS"))
    }
}
