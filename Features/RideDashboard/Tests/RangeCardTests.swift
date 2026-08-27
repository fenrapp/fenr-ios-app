import Foundation
@testable import RideDashboard
import RideSession
import RideSessionDomain
import Testing
import TestSupport

@MainActor
@Suite("Range card")
struct RangeCardTests {
    @Test("Maps adaptive range, consumption and battery charts")
    func mapsRangeCard() {
        let trip = activeTrip()
        let state = RangeCardMapper(
            locale: Locale(identifier: "en_GB"),
            estimator: RideRangeEstimator()
        ).map(
            snapshot: .init(
                trip: trip,
                vehicleIdentity: trip.vehicleIdentity,
                batteryStateOfChargePercent: 50,
                batteryCapacityWattHours: 7_200
            ),
            historicalTrips: [historicalTrip()],
            historyIsLoading: false
        )

        #expect(state.rangeText != "—")
        #expect(state.batteryText == "50%")
        #expect(state.remainingEnergyText == "3.6 kWh")
        #expect(state.consumptionPoints.count == 1)
        #expect(state.batteryPoints.count == 1)
        #expect(state.peakDischargeText == "12.0 kW")
        #expect(state.peakRegenerationText == "4.0 kW")
    }

    @Test("Loads history only while the range card is visible")
    func loadsHistoryLazily() async {
        let repository = CurrentTripCardTripRepository(completedTrips: [historicalTrip()])
        let session = TestRideSessionService(snapshot: .init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            batteryStateOfChargePercent: 60,
            batteryCapacityWattHours: 7_200
        ))
        let viewModel = RangeCardViewModel(
            useCases: .init(loadHistory: .init(repository: repository)),
            mapper: .init(locale: Locale(identifier: "en_GB"), estimator: RideRangeEstimator()),
            session: session
        )

        await Task.yield()
        #expect(await repository.loadCount() == 0)
        viewModel.setIsVisible(true)
        #expect(await waitUntil { await repository.loadCount() == 1 })
        viewModel.setIsVisible(false)
        await session.send(.init(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            historyRevision: 1
        ))
        await Task.yield()
        #expect(await repository.loadCount() == 1)
    }

    private func activeTrip() -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            distanceKilometers: 2,
            maximumDischargePowerWatts: 12_000,
            maximumRegenerationPowerWatts: 4_000,
            energyBuckets: [
                .init(
                    startedAt: .distantPast,
                    updatedAt: .distantFuture,
                    startDistanceKilometers: .zero,
                    endDistanceKilometers: 2,
                    stateOfChargePercent: 50,
                    consumedEnergyWattHours: 160,
                    recoveredEnergyWattHours: 20
                )
            ]
        )
    }

    private func historicalTrip() -> RideTrip {
        RideTrip(
            vehicleIdentity: .vin(CurrentTripTestIdentity.vin),
            applicationSessionID: UUID(),
            startedAt: .distantPast,
            endedAt: .distantPast,
            distanceKilometers: 10,
            consumedEnergyWattHours: 700,
            electricalObservedSeconds: 100,
            electricalExpectedSeconds: 100
        )
    }
}
