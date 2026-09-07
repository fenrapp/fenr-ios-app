import Foundation
import RideSessionDomain
import Testing

@Suite("Ride trip history use cases")
struct RideTripHistoryUseCaseTests {
    private let vehicleIdentifier = "FENRTEST000000001"

    @Test("Read failures propagate through history, detail and every aggregate", arguments: [
        RideTripReadError.readFailed, .invalidData
    ])
    func propagatesReadFailures(error: RideTripReadError) async {
        let repository = StubRideTripRepository(readError: error)
        await #expect(throws: error) {
            try await LoadRideTripHistoryUseCase(repository: repository).execute(vin: vehicleIdentifier)
        }
        await #expect(throws: error) {
            try await LoadRideTripDetailUseCase(repository: repository).execute(id: UUID(), vin: vehicleIdentifier)
        }
        await #expect(throws: error) {
            try await LoadRideTripRangeHistoryUseCase(repository: repository).execute(vin: vehicleIdentifier)
        }
        await #expect(throws: error) {
            try await LoadRideTripEfficiencyTrendUseCase(repository: repository).execute(vin: vehicleIdentifier)
        }
        await #expect(throws: error) {
            try await LoadRideTripStatisticsUseCase(repository: repository, aggregator: .init())
                .execute(vin: vehicleIdentifier)
        }
    }

    @Test("Filters partial and unconfirmed trips before limiting the efficiency trend")
    func filtersEfficiencyTrendBeforeLimit() async throws {
        let unconfirmed = makeTrip(dateOffset: 60, vehicleIdentity: .temporary(UUID()))
        let partial = makeTrip(dateOffset: 50, electricalCoverage: 0.5)
        let newestEligible = makeTrip(dateOffset: 40, efficiency: 10)
        let olderEligible = makeTrip(dateOffset: 30, efficiency: 20)
        let oldestEligible = makeTrip(dateOffset: 20, efficiency: 30)
        let repository = StubRideTripRepository(completedTrips: [
            unconfirmed,
            partial,
            newestEligible,
            olderEligible,
            oldestEligible
        ])

        let trips = try await LoadRideTripEfficiencyTrendUseCase(repository: repository).execute(
            vin: vehicleIdentifier,
            limit: 2
        )

        #expect(trips.map(\.id) == [olderEligible.id, newestEligible.id])
    }

    @Test("Keeps only finite positive range efficiencies in newest-first order")
    func filtersRangeHistoryBeforeLimit() async throws {
        let negative = makeTrip(dateOffset: 70, efficiency: -5)
        let nonfinite = makeTrip(dateOffset: 65, efficiency: .infinity)
        let zero = makeTrip(dateOffset: 60, efficiency: .zero)
        let partial = makeTrip(dateOffset: 50, efficiency: 5, electricalCoverage: 0.5)
        let newestEligible = makeTrip(dateOffset: 40, efficiency: 10)
        let olderEligible = makeTrip(dateOffset: 30, efficiency: 20)
        let oldestEligible = makeTrip(dateOffset: 20, efficiency: 30)
        let repository = StubRideTripRepository(completedTrips: [
            negative,
            nonfinite,
            zero,
            partial,
            newestEligible,
            olderEligible,
            oldestEligible
        ])

        let trips = try await LoadRideTripRangeHistoryUseCase(repository: repository).execute(
            vin: vehicleIdentifier,
            limit: 2
        )

        #expect(trips.map(\.id) == [newestEligible.id, olderEligible.id])
    }

    @Test("Returns no history for a nonpositive limit", arguments: [0, -1])
    func nonpositiveLimitReturnsEmpty(limit: Int) async throws {
        let repository = StubRideTripRepository(completedTrips: [makeTrip(dateOffset: 10)])

        let efficiencyTrips = try await LoadRideTripEfficiencyTrendUseCase(repository: repository).execute(
            vin: vehicleIdentifier,
            limit: limit
        )
        let rangeTrips = try await LoadRideTripRangeHistoryUseCase(repository: repository).execute(
            vin: vehicleIdentifier,
            limit: limit
        )

        #expect(efficiencyTrips.isEmpty)
        #expect(rangeTrips.isEmpty)
    }

    private func makeTrip(
        dateOffset: TimeInterval,
        vehicleIdentity: RideVehicleIdentity? = nil,
        efficiency: Double = 10,
        electricalCoverage: Double = 1
    ) -> RideTrip {
        let elapsedSeconds = 100.0
        return RideTrip(
            vehicleIdentity: vehicleIdentity ?? .vin(vehicleIdentifier),
            applicationSessionID: UUID(),
            startedAt: Date(timeIntervalSince1970: dateOffset),
            endedAt: Date(timeIntervalSince1970: dateOffset + elapsedSeconds),
            distanceKilometers: 2,
            consumedEnergyWattHours: efficiency * 2,
            electricalObservedSeconds: electricalCoverage * elapsedSeconds,
            electricalExpectedSeconds: elapsedSeconds
        )
    }
}
