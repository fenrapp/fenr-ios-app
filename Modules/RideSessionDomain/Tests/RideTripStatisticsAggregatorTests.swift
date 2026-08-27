import Foundation
import RideSessionDomain
import Testing

@Suite("Ride trip statistics aggregator")
struct RideTripStatisticsAggregatorTests {
    @Test("Aggregates one hundred trips in one weighted pass")
    func aggregatesMaximumHistory() {
        var trips: [RideTrip] = []
        for index in 1 ... 100 {
            trips.append(makeTrip(index: index))
        }

        let statistics = RideTripStatisticsAggregator().aggregate(trips)

        #expect(statistics.tripCount == 100)
        #expect(statistics.totalDistanceKilometers == 5_050)
        #expect(statistics.totalElapsedSeconds == 303_000)
        #expect(statistics.maximumSpeedKilometersPerHour == 120)
        #expect(abs(statistics.averageSpeedKilometersPerHour - 67) < 0.001)
    }

    @Test("Uses elapsed time for trips saved before weighted samples existed")
    func supportsLegacyTrips() {
        let trips = [
            RideTrip(
                vehicleIdentity: .vin("TESTVIN0000000001"),
                applicationSessionID: UUID(),
                startedAt: .distantPast,
                elapsedSeconds: 60,
                averageSpeedKilometersPerHour: 20
            ),
            RideTrip(
                vehicleIdentity: .vin("TESTVIN0000000001"),
                applicationSessionID: UUID(),
                startedAt: .distantPast,
                elapsedSeconds: 180,
                averageSpeedKilometersPerHour: 40
            )
        ]

        let statistics = RideTripStatisticsAggregator().aggregate(trips)

        #expect(statistics.averageSpeedKilometersPerHour == 35)
    }

    private func makeTrip(index: Int) -> RideTrip {
        let numericIndex = Double(index)
        let elapsedSeconds = numericIndex * 60
        return RideTrip(
            vehicleIdentity: .vin("TESTVIN0000000001"),
            applicationSessionID: UUID(),
            startedAt: Date(timeIntervalSinceReferenceDate: numericIndex),
            endedAt: Date(timeIntervalSinceReferenceDate: numericIndex + 1),
            distanceKilometers: numericIndex,
            elapsedSeconds: elapsedSeconds,
            averageSpeedKilometersPerHour: numericIndex,
            maximumSpeedKilometersPerHour: numericIndex + 20,
            accumulatedSpeedKilometersPerHourSeconds: numericIndex * elapsedSeconds,
            speedSampleDurationSeconds: elapsedSeconds
        )
    }
}
