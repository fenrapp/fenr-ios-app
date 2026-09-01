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

    @Test("Treats invalid persisted metrics as zero")
    func normalizesInvalidMetrics() {
        let invalidValues = [-1.0, Double.nan, Double.infinity]
        let trips = invalidValues.map { invalidValue in
            RideTrip(
                vehicleIdentity: .vin("FENRTEST000000001"),
                applicationSessionID: UUID(),
                startedAt: .distantPast,
                distanceKilometers: invalidValue,
                elapsedSeconds: invalidValue,
                averageSpeedKilometersPerHour: invalidValue,
                maximumSpeedKilometersPerHour: invalidValue,
                accumulatedSpeedKilometersPerHourSeconds: invalidValue,
                speedSampleDurationSeconds: invalidValue
            )
        }

        let statistics = RideTripStatisticsAggregator().aggregate(trips)

        #expect(statistics.tripCount == 3)
        #expect(statistics.totalDistanceKilometers == .zero)
        #expect(statistics.totalElapsedSeconds == .zero)
        #expect(statistics.averageSpeedKilometersPerHour == .zero)
        #expect(statistics.maximumSpeedKilometersPerHour == .zero)
    }

    @Test("Keeps valid totals finite when an invalid weighted trip is present")
    func preservesValidMetrics() {
        let validTrip = RideTrip(
            vehicleIdentity: .vin("FENRTEST000000001"),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            distanceKilometers: 8,
            elapsedSeconds: 60,
            averageSpeedKilometersPerHour: 40,
            maximumSpeedKilometersPerHour: 55,
            accumulatedSpeedKilometersPerHourSeconds: 2_400,
            speedSampleDurationSeconds: 60
        )
        let invalidTrip = RideTrip(
            vehicleIdentity: .vin("FENRTEST000000001"),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            distanceKilometers: .infinity,
            elapsedSeconds: .nan,
            averageSpeedKilometersPerHour: .infinity,
            maximumSpeedKilometersPerHour: .nan,
            accumulatedSpeedKilometersPerHourSeconds: .infinity,
            speedSampleDurationSeconds: 60
        )

        let statistics = RideTripStatisticsAggregator().aggregate([invalidTrip, validTrip])

        #expect(statistics.tripCount == 2)
        #expect(statistics.totalDistanceKilometers == 8)
        #expect(statistics.totalElapsedSeconds == 60)
        #expect(statistics.averageSpeedKilometersPerHour == 40)
        #expect(statistics.maximumSpeedKilometersPerHour == 55)
        #expect(statistics.totalDistanceKilometers.isFinite)
        #expect(statistics.totalElapsedSeconds.isFinite)
        #expect(statistics.averageSpeedKilometersPerHour.isFinite)
        #expect(statistics.maximumSpeedKilometersPerHour.isFinite)
    }

    @Test("Includes a finite zero legacy speed in the weighted average")
    func includesZeroLegacySpeed() {
        let trips = [0.0, 30.0].map { averageSpeed in
            RideTrip(
                vehicleIdentity: .vin("FENRTEST000000001"),
                applicationSessionID: UUID(),
                startedAt: .distantPast,
                elapsedSeconds: 60,
                averageSpeedKilometersPerHour: averageSpeed
            )
        }

        let statistics = RideTripStatisticsAggregator().aggregate(trips)

        #expect(statistics.averageSpeedKilometersPerHour == 15)
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
